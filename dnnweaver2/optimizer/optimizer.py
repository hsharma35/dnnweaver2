import math
import functools
import time
import logging

from itertools import permutations
from multiprocessing import Pool, cpu_count

from dnnweaver2.utils.utils import ceil_a_by_b, log2
from dnnweaver2.simulator.loop_stack import LoopStack
from dnnweaver2.simulator.stats import Stats

import numpy as np

logger = logging.getLogger('{}.{}'.format(__name__, 'Optimizer'))
logger.setLevel(logging.DEBUG)

tile_deps = {}
tile_deps['B/b']   = {'ibuf': True,  'wbuf': False, 'obuf': True,  'bbuf': False}
tile_deps['OW/ow'] = {'ibuf': True,  'wbuf': False, 'obuf': True,  'bbuf': False}
tile_deps['OH/oh'] = {'ibuf': True,  'wbuf': False, 'obuf': True,  'bbuf': False}
tile_deps['IC/ic'] = {'ibuf': True,  'wbuf': True,  'obuf': False, 'bbuf': False}
tile_deps['OC/oc'] = {'ibuf': False, 'wbuf': True,  'obuf': True,  'bbuf': True}

def get_stats_fast(conv_params, tiling, order_type, verbose=False):
    """
    Returns cycles and memory accesses to DRAM, IBUF, OBUF, and WBUF
        TODOs: Without im2col, the calculation of weight and ibuf size is inexact
    """
    acc_obj, K, O, S, IC, OC, B, iprec, wprec, im2col, energy_cost, _, _ = conv_params

    num_b, b = tiling['B/b']
    num_ow, ow = tiling['OW/ow']
    num_oh, oh = tiling['OH/oh']
    num_ic, ic = tiling['IC/ic']
    num_oc, oc = tiling['OC/oc']

    kw = kh = K

    ih = (oh - 1) * S + kh
    iw = (ow - 1) * S + kw

    writes = {}
    reads = {}

    writes['wbuf'] = \
            ceil_a_by_b(ic, acc_obj.N) * acc_obj.N * kh * kw * \
            ceil_a_by_b(oc, acc_obj.M) * acc_obj.M * \
            wprec

    writes['ibuf'] = iw * ih * ceil_a_by_b(ic, acc_obj.N) * acc_obj.N * b * iprec

    bprec = 32
    writes['bbuf'] = ceil_a_by_b(oc, acc_obj.M) * acc_obj.M * bprec

    oprec = 64
    writes['obuf'] = ow * oh * ceil_a_by_b(oc, acc_obj.M) * acc_obj.M * b * oprec
    reads['obuf'] = ow * oh * ceil_a_by_b(oc, acc_obj.M) * acc_obj.M * b * oprec

    # Skip if overutilizing resources
    overflow = False
    for namespace in writes:
        if writes[namespace] > acc_obj.sram[namespace]/2:
            overflow = True
    if overflow:
        return

    max_write_size = {}
    max_read_size = {}
    for namespace in writes:
        max_write_size[namespace] = writes[namespace]
        if verbose:
            print('{}: {:,} bits'.format(namespace, max_write_size[namespace]))
    for namespace in reads:
        max_read_size[namespace] = reads[namespace]

    # First the loop block optimizations
    stats = Stats()
    rd_cache_hit = {'wbuf': True, 'ibuf': True, 'obuf': True, 'bbuf': True}
    wr_cache_hit = {'obuf': True}
    if verbose:
        logger.debug('Initialize reads/writes')
        logger.debug('\tim2col: {}'.format(im2col))
        logger.debug('\tTiling: {}'.format(tiling))
        logger.debug('\tReads : {}'.format(reads))
        logger.debug('\tWrites: {}'.format(writes))

    for loop in order_type:
        num_tiles, tile_size = tiling[loop]
        for namespace in writes:
            if rd_cache_hit[namespace]:
                if tile_deps[loop][namespace]:
                    writes[namespace] *= num_tiles
                    rd_cache_hit[namespace] = False
            else:
                writes[namespace] *= num_tiles

        for namespace in reads:
            if wr_cache_hit[namespace]:
                if tile_deps[loop][namespace]:
                    reads[namespace] *= num_tiles
                    wr_cache_hit[namespace] = False
            else:
                reads[namespace] *= num_tiles

        if verbose:
            logger.debug('Loop: {}'.format(loop))
            logger.debug('\tLoop range: {}'.format(tiling[loop]))
            logger.debug('\tMax write size: {}'.format(max_write_size))
            logger.debug('\tMax read size: {}'.format(max_read_size))
            logger.debug('\tLoop Dependencies: {}'.format(tile_deps[loop]))
            logger.debug('\tLoop Promote: {}'.format(rd_cache_hit))
            logger.debug('\tReads : {}'.format(reads))
            logger.debug('\tWrites: {}'.format(writes))

    for namespace in writes:
        stats.writes[namespace] = writes[namespace]
        stats.reads['dram'] += writes[namespace]
    for namespace in reads:
        stats.reads[namespace] = reads[namespace]
        stats.writes['dram'] += reads[namespace]

    is_loop = ceil_a_by_b(oc, acc_obj.M) * acc_obj.M
    os_loop = ceil_a_by_b(ic, acc_obj.N) * acc_obj.N * kh * kw
    ws_loop = b * oh * ow
    # Input Stationary energy
    # kw * kh * ic * oh * ow * b -> oc
    is_energy = (os_loop * ws_loop) * (iprec    + is_loop * (wprec + oprec))
    # Output Stationary energy
    # oc * oh * ow * b -> kw * kh * ic
    os_energy = (is_loop * ws_loop) * (oprec    + os_loop * (iprec + wprec))
    # Weight Stationary energy
    # kw * kh * ic * oc -> b * ow * oh
    ws_energy = (os_loop * is_loop) * (wprec    + ws_loop * (iprec + oprec))

    min_energy = min(is_energy, ws_energy, os_energy)
    num_tiles = num_b * num_ow * num_oh * num_ic * num_oc

    if is_energy == min_energy:
        if verbose:
            logger.debug('SRAM access order: Input Stationary')
        stats.reads['ibuf'] += num_tiles * (kw * kh * ic * oh * ow * b) * iprec
        stats.reads['obuf'] += num_tiles * (kw * kh * ic * oh * ow * b) * oc * oprec
        stats.writes['obuf'] += num_tiles * (kw * kh * ic * oh * ow * b) * oc * oprec
        stats.reads['wbuf'] += num_tiles * (kw * kh * ic * oh * ow * b) * oc * wprec

    elif os_energy == min_energy:
        if verbose:
            logger.debug('SRAM access order: Output Stationary')
        stats.reads['ibuf'] += num_tiles * (oc * oh * ow * b) * (kw * kh * ic) * iprec
        stats.reads['obuf'] += num_tiles * (oc * oh * ow * b) * oprec
        stats.writes['obuf'] += num_tiles * (oc * oh * ow * b) * oprec
        stats.reads['wbuf'] += num_tiles * (oc * oh * ow * b) * (kw * kh * ic) * wprec

    else:
        if verbose:
            logger.debug('SRAM access order: Weight Stationary')
        stats.reads['ibuf'] += num_tiles * (kw * kh * ic * oc) * (b * ow * oh) * iprec
        stats.reads['obuf'] += num_tiles * (kw * kh * ic * oc) * (b * ow * oh) * oprec
        stats.writes['obuf'] += num_tiles * (kw * kh * ic * oc) * (b * ow * oh) * oprec
        stats.reads['wbuf'] += num_tiles * (kw * kh * ic * oc) * wprec

    # TODO: update
    initial_dram_reads = 0
    final_dram_writes = 0
    for namespace in max_write_size:
        initial_dram_reads += max_write_size[namespace]
    for namespace in max_read_size:
        final_dram_writes += max_read_size[namespace]
    latency = acc_obj.get_mem_read_cycles('dram', initial_dram_reads) + \
            acc_obj.get_mem_write_cycles('dram', final_dram_writes)

    total_dram_accesses = stats.reads['dram'] + stats.writes['dram']
    middle_dram_accesses = total_dram_accesses - initial_dram_reads - final_dram_writes


    compute_cycles = num_tiles * acc_obj.get_compute_cycles(ic, oc, ow, oh, b, kw, kh, iprec, wprec, im2col)
    memory_cycles_required = ceil_a_by_b(middle_dram_accesses, acc_obj.mem_if_width)

    memory_stalls = max(0, memory_cycles_required - compute_cycles) + latency
    stats.total_cycles = compute_cycles + memory_stalls
    stats.mem_stall_cycles = memory_stalls

    if verbose:
        logger.debug('Compute cycles : {:>20,}'.format(compute_cycles))
        logger.debug('Memory cycles  : {:>20,}'.format(memory_cycles_required + latency))
        logger.debug('Memory stalls  : {:>20,}'.format(memory_stalls))

    return stats

def optimize_for_order(conv_params, pool_kernel=None, pool_stride=None, sequential=True):
    # Generate permutations for the order
    loops = ['B/b', 'OW/ow', 'OH/oh', 'IC/ic', 'OC/oc']
    order = set(permutations(loops))

    return_dict = {}
    acc_obj, K, O, S, IC, OC, B, iprec, wprec, im2col, energy_cost = conv_params

    #print('optimizing for convolution layer: weights {}x{}x{}x{}'.format(OC,IC,K,K))
    #print('Batch size: {}'.format(B))

    if pool_kernel is None:
        pool_kernel = (1,1,1,1)
    if pool_stride is None:
        pool_stride = (1,1,1,1)
    conv_params_with_pool = acc_obj, K, O, S, IC, OC, B, iprec, wprec, im2col, energy_cost, pool_kernel, pool_stride

    if not sequential:
        _bound_optimizer_method = functools.partial(_optimize_for_order, conv_params_with_pool)

        try:
            pool = Pool(cpu_count())
            results = pool.map_async(_bound_optimizer_method, order).get(10000)
            pool.close()
            pool.join()

            # for o in order:
            #     _bound_optimizer_method(o)
            # exit()

            best_cycles = None
            best_energy = None
            min_cycles = min([x[-4] for x in results])
            min_energy = min([x[-3] for x in results])
            cycles_list = [x[-2] for x in results]
            energy_list = [x[-1] for x in results]
            energy_array = np.stack(energy_list)
            cycles_array = np.stack(cycles_list)
            for r in results:
                tiling, order_type, cycles, energy, _, _ = r
                # print('{}:\n{}\n\t{:1.2f}, {:1.2f}'.format(order_type, tiling, cycles/float(min_cycles), energy/float(min_energy)))
                if best_cycles is None or best_cycles > cycles or (best_cycles == cycles and best_energy > energy):
                    best_cycles = cycles
                    best_energy = energy
                    best_tiling = tiling
                    best_order = order_type
            return best_tiling, best_order, cycles_array, energy_array

        except KeyboardInterrupt:
            pool.terminate()
            pool.join()
            return

    else:
        best_cycles = None
        best_energy = None
        best_tiling = None
        best_order  = None
        for o in order:
            tiling, order_type, cycles, energy, _, _ = _optimize_for_order(conv_params_with_pool, o)
            if best_cycles is None or best_cycles > cycles:
                best_cycles = cycles
                best_energy = energy
                best_tiling = tiling
                best_order  = order_type
            elif best_cycles == cycles and best_energy > energy:
                best_cycles = cycles
                best_energy = energy
                best_tiling = tiling
                best_order  = order_type
        return best_tiling, best_order, None, None

def _optimize_for_order(conv_params, order_type, verbose=False):
    """
    For a given ordering, optimizes tiling
    Args:
        conv_params: A tuple with convolution params
        order_type: ordering loop
    """
    acc_obj, K, O, S, IC, OC, B, iprec, wprec, im2col, energy_cost, pool_kernel, pool_stride = conv_params
    I = (O - 1) * S + K

    pool_O = (O - pool_kernel[1]) / pool_stride[1] + 1

    # print('Pool output: {}'.format(pool_O))

    # We do not tile the "K" dimension and compute an entire 2-D conv at a
    # time
    num_O_tiles = int(math.ceil(log2(pool_O))) + 1
    num_IC_tiles = int(math.ceil(log2(IC))) + 1

    # TODO: Fix?
    if im2col:
        num_OC_tiles = int(math.ceil(log2(OC))) + 1
    else:
        num_OC_tiles = int(math.ceil(log2(math.ceil(float(OC)/acc_obj.M)))) + 1

    num_B_tiles = int(math.ceil(log2(B))) + 1

    best_cycles = None
    best_energy = None
    best_tiling = None

    cycle_array = np.zeros((num_B_tiles, num_O_tiles, num_IC_tiles, num_OC_tiles), dtype=np.float)
    energy_array = np.zeros((num_B_tiles, num_O_tiles, num_IC_tiles, num_OC_tiles), dtype=np.float)

    for _b in range(num_B_tiles):
        b = min(1 << _b, B)
        num_b = ceil_a_by_b(B, b)

        for _o in range(num_O_tiles):
            p_ow = min(1 << _o, pool_O)
            p_oh = p_ow
            ow = (p_ow-1) * pool_stride[1] + pool_kernel[1]
            oh = (p_oh-1) * pool_stride[2] + pool_kernel[2]
            num_ow = ceil_a_by_b(pool_O, p_ow)
            num_oh = ceil_a_by_b(pool_O, p_oh)

            if num_ow * p_ow != pool_O:
                # print('p_ow: {}; ow: {}; num_ow: {}'.format(p_ow, ow, num_ow))
                continue

            for _ic in range(num_IC_tiles):
                ic = min(1 << _ic, IC)
                num_ic = ceil_a_by_b(IC, ic)

                for _oc in range(num_OC_tiles):

                    if im2col:
                        oc = min((1 << _oc), OC)
                    else:
                        oc = min((1 << _oc) * acc_obj.M, OC)

                    num_oc = ceil_a_by_b(OC, oc)

                    iw = K + (ow - 1) * S
                    ih = K + (oh - 1) * S

                    tiling = {}
                    tiling['B/b'] = (num_b, b)
                    tiling['OW/ow'] = (num_ow, ow)
                    tiling['OH/oh'] = (num_oh, oh)
                    tiling['IC/ic'] = (num_ic, ic)
                    tiling['OC/oc'] = (num_oc, oc)

#                     print(tiling)

                    stats = get_stats_fast(conv_params, tiling, order_type, verbose=verbose)
                    #break
                    if stats is None:
                        continue

                    cycles = stats.total_cycles
                    cycle_array[_b, _o, _ic, _oc] = cycles
                    energy = stats.get_energy(energy_cost)
                    energy_array[_b, _o, _ic, _oc] = energy
                    mem_cycles = stats.mem_stall_cycles

                    # fail = stats.total_cycles > 1.1* stats.total_cycles
                    # fail += stats.total_cycles < 0.9* stats.total_cycles
                    # if fail > 0:
                    #     logger.error('Simulated cycles: {:,}'.format(cycles))
                    #     logger.error('Simulated memory cycles: {:,}'.format(mem_cycles))
                    #     logger.error('new cycles: {:,}'.format(stats.total_cycles))
                    #     logger.error('new memory cycles: {:,}'.format(stats.mem_stall_cycles))
                    #     get_stats_fast(conv_params, tiling, order_type, verbose=True)
                    #     exit()

                    if best_cycles is None or best_cycles > cycles or (best_cycles == cycles and best_energy > energy):
                    # if best_energy is None or best_energy > energy or (best_energy == energy and best_cycles > cycles):
                        best_energy = energy
                        best_cycles = cycles
                        best_mem_cycles = mem_cycles
                        best_order = order_type
                        best_tiling = tiling
                        # for o in best_order:
                            # best_tiling.append(tiling[o])

#     if best_cycles is None:
# #         print('Not found')
# #         print(conv_params)
#         stats = get_stats_fast(conv_params, tiling, order_type, verbose=True)

    return (best_tiling, order_type, best_cycles, best_energy, cycle_array, energy_array)
