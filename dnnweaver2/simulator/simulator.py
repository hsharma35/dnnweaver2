import logging
import math
import ConfigParser
import numpy as np

from nn_dataflow import ConvLayer

from src.utils.utils import ceil_a_by_b, log2, lookup_pandas_dataframe
from src.simulator.stats import Stats
from src.simulator.loop_stack import LoopStack
from src.optimizer.optimizer import optimize_for_order, get_stats_fast
from src.simulator.accelerator import Accelerator

from sram.sram_stats import get_sram_dataframe, get_sram_data
import os
import pandas

class Simulator(object):
    """
    Simulator class
    """

    def __init__(self, config_file='conf.ini', verbose=False, energy_costs=None):

        # custom energy cost
        self.energy_costs = energy_costs

        self.config_file = config_file

        self.config = ConfigParser.ConfigParser()
        self.config.read(config_file)

        systolic_dim = [self.config.getint('accelerator', 'a'),
                             1,
                             self.config.getint('accelerator', 'c')]

        if verbose:
            log_level = logging.DEBUG
        else:
            log_level = logging.INFO

        # logging.basicConfig(level=log_level)
        self.logger = logging.getLogger('{}.{}'.format(__name__, 'Simulator'))
        self.logger.setLevel(log_level)
        self.logger.debug("Creating Simulator Object")
        self.logger.debug("Systolic Array dimentions: {}".format(systolic_dim))

        mem_if_width = self.config.getint('system', 'if_width')
        self.logger.debug("Memory Interface Bit-Width: {}-bits".format(mem_if_width))

        pmax = self.config.getint('accelerator', 'high_prec')
        pmin = self.config.getint('accelerator', 'low_prec')
        self.logger.debug("High Precision: {}-bits".format(pmax))
        self.logger.debug("Low Precision: {}-bits".format(pmin))

        # Using half the size assuming double buffering
        sram = {}

        sram['act'] = self.config.getint('accelerator', 'Act_SRAM')
        self.logger.debug("Activation SRAM size: {:,} Bytes".format(sram['act']))

        sram['wgt'] = self.config.getint('accelerator', 'Wgt_SRAM')
        self.logger.debug("Weight SRAM size: {:,} Bytes".format(sram['wgt']))

        sram['out'] = self.config.getint('accelerator', 'Out_SRAM')
        self.logger.debug("Output SRAM size: {:,} Bytes".format(sram['out']))

        frequency = self.config.getint('accelerator', 'frequency')
        self.logger.debug('Frequency: {:,} Hz'.format(frequency))

        hp_peak_throughput = systolic_dim[0] * \
                             systolic_dim[1] * \
                             systolic_dim[2]
        peak_throughput = hp_peak_throughput * \
                               (int(pmax / pmin) ** 2)
        self.logger.debug('Lowest  precision: Peak Throughput: {:,} Ops/cycle'.format(peak_throughput))
        self.logger.debug('Highest precision: Peak Throughput: {:,} Ops/cycle'.format(hp_peak_throughput))

        N = systolic_dim[0]
        beta = systolic_dim[1]
        M = systolic_dim[2]

        assert beta == 1

        self.accelerator = Accelerator(N, M, pmax, pmin, sram, mem_if_width, frequency)

        ##################################################
        # Get stats for SRAM
        frequency = self.accelerator.frequency
        tech_node = 45
        voltage = 0.85
        sram_csv = 'hardware_sweep/sram_results.csv'
        self.sram_df = get_sram_dataframe(tech_node, voltage, int(frequency * 1.e-6), './sram/data',
                                       logpath='./sram/mcpat.sram/SampleScirpts/RunLog')


    def get_area(self):
        frequency = self.accelerator.frequency
        ##################################################
        N = self.accelerator.N
        M = self.accelerator.M
        pmax = self.accelerator.pmax
        pmin = self.accelerator.pmin
        wbuf_size = self.accelerator.sram['wgt'] * 8
        ibuf_size = self.accelerator.sram['act'] * 8
        obuf_size = self.accelerator.sram['out'] * 8
        wbuf_bank = N * 2
        ibuf_bank = N * 2
        obuf_bank = 2
        wbuf_bits = (pmax * pmax / pmin) * M
        ibuf_bits = (pmax * pmax / pmin)
        obuf_bits = 32 * M
        wbuf_word = ceil_a_by_b(wbuf_size, wbuf_bank * wbuf_bits)
        ibuf_word = ceil_a_by_b(ibuf_size, ibuf_bank * ibuf_bits)
        obuf_word = ceil_a_by_b(obuf_size, obuf_bank * obuf_bits)

        ##################################################
        wbuf_area, wbuf_leak_power, wbuf_read_energy, wbuf_write_energy = get_sram_data(self.sram_df, wbuf_bits, wbuf_size/8, wbuf_bank, 2)
        self.logger.debug('WBUF :')
        self.logger.debug('\tBanks                       : {0:>8}'.format(wbuf_bank))
        self.logger.debug('\tBitWidth                    : {0:>8}'.format(wbuf_bits))
        self.logger.debug('\tWords                       : {0:>8}'.format(wbuf_word))
        self.logger.debug('\tTotal Size (kBytes)         : {0:>8}'.format(wbuf_size/8./1024.))
        self.logger.debug('\tArea                        : {0:>8.2f}'.format(wbuf_area))
        self.logger.debug('\tLeak Energy (per clock)     : {0:>8.6f}'.format(wbuf_leak_power))
        self.logger.debug('\tRead Energy (per bit) (nJ)  : {0:>8.6f}'.format(wbuf_read_energy))
        self.logger.debug('\tWrite Energy (per bit) (nJ) : {0:>8.6f}'.format(wbuf_write_energy))
        ##################################################
        ibuf_area, ibuf_leak_power, ibuf_read_energy, ibuf_write_energy = get_sram_data(self.sram_df, ibuf_bits, ibuf_size/8, ibuf_bank, 2)
        self.logger.debug('IBUF :')
        self.logger.debug('\tBanks                       : {0:>8}'.format(ibuf_bank))
        self.logger.debug('\tBitWidth                    : {0:>8}'.format(ibuf_bits))
        self.logger.debug('\tWords                       : {0:>8}'.format(ibuf_word))
        self.logger.debug('\tTotal Size (kBytes)         : {0:>8}'.format(ibuf_size/8./1024.))
        self.logger.debug('\tArea                        : {0:>8.2f}'.format(ibuf_area))
        self.logger.debug('\tLeak Energy (per clock)     : {0:>8.6f}'.format(ibuf_leak_power))
        self.logger.debug('\tRead Energy (per bit) (nJ)  : {0:>8.6f}'.format(ibuf_read_energy))
        self.logger.debug('\tWrite Energy (per bit) (nJ) : {0:>8.6f}'.format(ibuf_write_energy))
        ##################################################
        obuf_area, obuf_leak_power, obuf_read_energy, obuf_write_energy = get_sram_data(self.sram_df, obuf_bits, obuf_size/8, obuf_bank, 2)
        self.logger.debug('OBUF :')
        self.logger.debug('\tBanks                       : {0:>8}'.format(obuf_bank))
        self.logger.debug('\tBitWidth                    : {0:>8}'.format(obuf_bits))
        self.logger.debug('\tWords                       : {0:>8}'.format(obuf_word))
        self.logger.debug('\tTotal Size (kBytes)         : {0:>8}'.format(obuf_size/8./1024.))
        self.logger.debug('\tArea                        : {0:>8.2f}'.format(obuf_area))
        self.logger.debug('\tLeak Energy (per clock)     : {0:>8.6f}'.format(obuf_leak_power))
        self.logger.debug('\tRead Energy (per bit) (nJ)  : {0:>8.6f}'.format(obuf_read_energy))
        self.logger.debug('\tWrite Energy (per bit) (nJ) : {0:>8.6f}'.format(obuf_write_energy))
        ##################################################
        # Get stats for systolic array
        core_csv = os.path.join('./results', 'systolic_array_synth.csv')
        core_synth_data = pandas.read_csv(core_csv)

        lookup_dict = {}
        lookup_dict['Max Precision (bits)'] = pmax
        lookup_dict['Min Precision (bits)'] = pmin
        lookup_dict['N'] = N
        lookup_dict['M'] = M
        core_data = lookup_pandas_dataframe(core_synth_data, lookup_dict)
        if len(core_data) == 0:
            lookup_dict['N'] = 4
            lookup_dict['M'] = 4
            core_data = lookup_pandas_dataframe(core_synth_data, lookup_dict)
            assert len(core_data) == 1
            core_area = float(core_data['Area (um^2)']) * 1.e-6 * (N * M) / 16.
            core_dyn_power = float(core_data['Dynamic Power (nW)']) * (N * M) / 16.
            core_dyn_energy = core_dyn_power / float(core_data['Frequency'])
            core_leak_power = float(core_data['Leakage Power (nW)']) * (N * M) / 16.
            core_leak_energy = core_leak_power / float(core_data['Frequency'])
        else:
            core_area = float(core_data['Area (um^2)']) * 1.e-6
            core_dyn_power = float(core_data['Dynamic Power (nW)'])
            core_dyn_energy = core_dyn_power / float(core_data['Frequency'])
            core_leak_power = float(core_data['Leakage Power (nW)'])
            core_leak_energy = core_leak_power / float(core_data['Frequency'])
        self.logger.debug('Core :')
        self.logger.debug('\tDimensions              : {0}x{1}-systolic array'.format(N, M))
        self.logger.debug('\tMax-Precision           : {}'.format(pmax))
        self.logger.debug('\tMin-Precision           : {}'.format(pmin))
        self.logger.debug('\tLeak Energy (nJ)        : {}'.format(core_leak_energy))
        self.logger.debug('\tDynamic Energy (nJ)     : {}'.format(core_dyn_energy))
        self.logger.debug('\tArea (mm^2)             : {}'.format(core_area))
        ##################################################

        return core_area, wbuf_area, ibuf_area, obuf_area

    def get_energy_cost(self):

        if self.energy_costs is not None:
            return self.energy_costs

        frequency = self.accelerator.frequency
        ##################################################
        N = self.accelerator.N
        M = self.accelerator.M
        pmax = self.accelerator.pmax
        pmin = self.accelerator.pmin
        wbuf_size = self.accelerator.sram['wgt'] * 8
        ibuf_size = self.accelerator.sram['act'] * 8
        obuf_size = self.accelerator.sram['out'] * 8
        wbuf_bank = N * 2
        ibuf_bank = N * 2
        obuf_bank = 2
        wbuf_bits = (pmax * pmax / pmin) * M
        ibuf_bits = (pmax * pmax / pmin)
        obuf_bits = 32 * M
        wbuf_word = ceil_a_by_b(wbuf_size, wbuf_bank * wbuf_bits)
        ibuf_word = ceil_a_by_b(ibuf_size, ibuf_bank * ibuf_bits)
        obuf_word = ceil_a_by_b(obuf_size, obuf_bank * obuf_bits)

        ##################################################
        wbuf_area, wbuf_leak_power, wbuf_read_energy, wbuf_write_energy = get_sram_data(self.sram_df, wbuf_bits, wbuf_size/8, wbuf_bank, 2)
        self.logger.debug('WBUF :')
        self.logger.debug('\tBanks                       : {0:>8}'.format(wbuf_bank))
        self.logger.debug('\tBitWidth                    : {0:>8}'.format(wbuf_bits))
        self.logger.debug('\tWords                       : {0:>8}'.format(wbuf_word))
        self.logger.debug('\tTotal Size (kBytes)         : {0:>8}'.format(wbuf_size/8./1024.))
        self.logger.debug('\tArea                        : {0:>8.2f}'.format(wbuf_area))
        self.logger.debug('\tLeak Energy (per clock)     : {0:>8.6f}'.format(wbuf_leak_power))
        self.logger.debug('\tRead Energy (per bit) (nJ)  : {0:>8.6f}'.format(wbuf_read_energy))
        self.logger.debug('\tWrite Energy (per bit) (nJ) : {0:>8.6f}'.format(wbuf_write_energy))
        ##################################################
        ibuf_area, ibuf_leak_power, ibuf_read_energy, ibuf_write_energy = get_sram_data(self.sram_df, ibuf_bits, ibuf_size/8, ibuf_bank, 2)
        self.logger.debug('IBUF :')
        self.logger.debug('\tBanks                       : {0:>8}'.format(ibuf_bank))
        self.logger.debug('\tBitWidth                    : {0:>8}'.format(ibuf_bits))
        self.logger.debug('\tWords                       : {0:>8}'.format(ibuf_word))
        self.logger.debug('\tTotal Size (kBytes)         : {0:>8}'.format(ibuf_size/8./1024.))
        self.logger.debug('\tArea                        : {0:>8.2f}'.format(ibuf_area))
        self.logger.debug('\tLeak Energy (per clock)     : {0:>8.6f}'.format(ibuf_leak_power))
        self.logger.debug('\tRead Energy (per bit) (nJ)  : {0:>8.6f}'.format(ibuf_read_energy))
        self.logger.debug('\tWrite Energy (per bit) (nJ) : {0:>8.6f}'.format(ibuf_write_energy))
        ##################################################
        obuf_area, obuf_leak_power, obuf_read_energy, obuf_write_energy = get_sram_data(self.sram_df, obuf_bits, obuf_size/8, obuf_bank, 2)
        self.logger.debug('OBUF :')
        self.logger.debug('\tBanks                       : {0:>8}'.format(obuf_bank))
        self.logger.debug('\tBitWidth                    : {0:>8}'.format(obuf_bits))
        self.logger.debug('\tWords                       : {0:>8}'.format(obuf_word))
        self.logger.debug('\tTotal Size (kBytes)         : {0:>8}'.format(obuf_size/8./1024.))
        self.logger.debug('\tArea                        : {0:>8.2f}'.format(obuf_area))
        self.logger.debug('\tLeak Energy (per clock)     : {0:>8.6f}'.format(obuf_leak_power))
        self.logger.debug('\tRead Energy (per bit) (nJ)  : {0:>8.6f}'.format(obuf_read_energy))
        self.logger.debug('\tWrite Energy (per bit) (nJ) : {0:>8.6f}'.format(obuf_write_energy))
        ##################################################
        # Get stats for systolic array
        core_csv = os.path.join('./results', 'systolic_array_synth.csv')
        core_synth_data = pandas.read_csv(core_csv)

        lookup_dict = {}
        lookup_dict['Max Precision (bits)'] = pmax
        lookup_dict['Min Precision (bits)'] = pmin
        lookup_dict['N'] = N
        lookup_dict['M'] = M
        core_data = lookup_pandas_dataframe(core_synth_data, lookup_dict)
        if len(core_data) == 0:
            lookup_dict['N'] = 4
            lookup_dict['M'] = 4
            core_data = lookup_pandas_dataframe(core_synth_data, lookup_dict)
            assert len(core_data) == 1
            core_area = float(core_data['Area (um^2)']) * 1.e-6 * (N * M) / 16.
            core_dyn_power = float(core_data['Dynamic Power (nW)']) * (N * M) / 16.
            core_dyn_energy = core_dyn_power / float(core_data['Frequency'])
            core_leak_power = float(core_data['Leakage Power (nW)']) * (N * M) / 16.
            core_leak_energy = core_leak_power / float(core_data['Frequency'])
        else:
            core_area = float(core_data['Area (um^2)']) * 1.e-6
            core_dyn_power = float(core_data['Dynamic Power (nW)'])
            core_dyn_energy = core_dyn_power / float(core_data['Frequency'])
            core_leak_power = float(core_data['Leakage Power (nW)'])
            core_leak_energy = core_leak_power / float(core_data['Frequency'])
        self.logger.debug('Core :')
        self.logger.debug('\tDimensions              : {0}x{1}-systolic array'.format(N, M))
        self.logger.debug('\tMax-Precision           : {}'.format(pmax))
        self.logger.debug('\tMin-Precision           : {}'.format(pmin))
        self.logger.debug('\tLeak Energy (nJ)        : {}'.format(core_leak_energy))
        self.logger.debug('\tDynamic Energy (nJ)     : {}'.format(core_dyn_energy))
        self.logger.debug('\tArea (mm^2)             : {}'.format(core_area))
        ##################################################

        total_leak_energy = core_leak_energy + (wbuf_leak_power + ibuf_leak_power + obuf_leak_power) * 1.e9 / frequency

        return total_leak_energy, core_dyn_energy, wbuf_read_energy, wbuf_write_energy, ibuf_read_energy, ibuf_write_energy, obuf_read_energy, obuf_write_energy


    def __str__(self):
        ret = ''
        ret += 'Simulator object'
        ret += '\n'
        ret += '\tMax supported precision: {}'.format(self.accelerator.pmax)
        ret += '\n'
        ret += '\tMin supported precision: {}'.format(self.accelerator.pmin)
        ret += '\n'
        ret += '\tSystolic array size: {} -inputs x {} -outputs'.format(
                self.accelerator.N,
                self.accelerator.M)

        ret += '\n'
        ret += '\tWbuf size: {:,} Bytes'.format(self.accelerator.sram['wgt'])
        ret += '\n'
        ret += '\tIbuf size: {:,} Bytes'.format(self.accelerator.sram['act'])
        ret += '\n'
        ret += '\tObuf size: {:,} Bytes'.format(self.accelerator.sram['out'])
        ret += '\n'
        ret += 'Double buffering enabled. Sizes of SRAM are halved'
        return ret

    def loop_estimate_stats(self, loop_instruction, verbose=False):
        """
        args:
            loop_instruction: Loops for the NN.
                index 0 = outer loop
                index -1 = inner loop
        """

        # The following loop promotes Memory accesses to improve reuse
        loop_instruction.promote_mem_ops(self.accelerator.sram)
        # get stats
        stats = loop_instruction.get_stats(self.accelerator, verbose)

        return stats


    def get_FC_cycles(self, Ni, No,
                      iprec, wprec,
                      batch_size=1):
        """
        Get number of cycles required for Fully-Connected Layer.

        args:
            Ni: Input neurons
            No: Output neurons
            batch_size: Batch size for FC layer
            iprec: Precision for activations (bits)
            wprec: Precision for weights (bits)
            batch_size: Batch size for the layer

        description:
            This function calls the get_conv_cycles function
        """
        total_cycles = self.get_conv_cycles(1, 1, 1, Ni, No, iprec, wprec, batch_size)

        return total_cycles

    def get_perf_factor(self, iprec, wprec):
        iprec = max(iprec, self.accelerator.pmin)
        wprec = max(wprec, self.accelerator.pmin)
        return int(self.accelerator.pmax / iprec) * int(self.accelerator.pmax / wprec)

    def get_conv_cycles(self, K, O, S, IC, OC, iprec, wprec, batch_size=1, im2col=False):
        """
        Get number of cycles required for Fully-Connected Layer.

        args:
            K: Kernel Size
            O: Output Size
            S: Input Stride
            IC: Input Channels
            OC: Output Channels
            iprec: Precision for activations (bits)
            wprec: Precision for weights (bits)
            batch_size: Batch size for the layer

        description:
            This functions does an exhaustive search for finding the optimal
            Tiling and Ordering parameters

        assumptions:
            (1) uses an estimate of the compute cycles, instead of actually
            simulating the number of cycles
        """
        B = batch_size
        I = (O - 1) * S + K

        # We do not tile the "K" dimension and compute an entire 2-D conv at a
        # time
        num_O_tiles = int(math.ceil(log2(O))) + 1
        num_IC_tiles = int(math.ceil(log2(IC))) + 1
        num_OC_tiles = int(math.ceil(log2(math.ceil(float(OC)/self.accelerator.M)))) + 1
        num_B_tiles = int(math.ceil(log2(B))) + 1

        self.logger.debug('Number of O Tiles: {}'.format(num_O_tiles))
        self.logger.debug('Number of IC Tiles: {}'.format(num_IC_tiles))
        self.logger.debug('Number of OC Tiles: {}'.format(num_OC_tiles))
        self.logger.debug('Number of B Tiles: {}'.format(num_B_tiles))

        best_instructions_dict = {}
        conv_params = self.accelerator, K, O, S, IC, OC, B, iprec, wprec, im2col, self.get_energy_cost()

        best_instructions, best_tiling, best_order, _, _ = optimize_for_order(conv_params)
        stats = get_stats_fast(conv_params, best_tiling, best_order, verbose=False)

        act_reads = stats.reads['act']
        wgt_reads = stats.reads['wgt']
        out_reads = stats.reads['out']
        dram_reads = stats.reads['dram']
        out_writes = stats.writes['out']
        dram_writes = stats.writes['dram']
        best_cycles = stats.total_cycles

        num_ops = O * O * K * K * IC * OC * B

        # self.logger.debug('Best Operations: {}'.format(best_operations))

        self.logger.debug('Conv Layer')
        self.logger.debug('Num of ops: {}'.format(num_ops))
        self.logger.debug('Kernel Size: {}x{}x{}x{}'.format(K, K, IC, OC))
        self.logger.debug('Output Size: {}x{}x{}'.format(O, O, OC))
        self.logger.debug('Stride Size: {}x{}'.format(S, S))
        self.logger.debug('Input  Size: {}x{}x{}'.format(I, I, IC))

        self.logger.debug('Max Precision: {}'.format(self.accelerator.pmax))
        self.logger.debug('Min Precision: {}'.format(self.accelerator.pmin))

        self.logger.debug('Activation Precision: {}'.format(iprec))
        self.logger.debug('Weight Precision: {}'.format(wprec))
        self.logger.debug('Performance Factor: {}'.format(self.get_perf_factor(iprec, wprec)))

        self.logger.debug('Total Cycles: {:,}'.format(best_cycles))
        cycles_per_batch = ceil_a_by_b(best_cycles, batch_size)
        self.logger.debug('Total Cycles per batch: {:,}'.format(cycles_per_batch))
        ops_per_cycle = float(num_ops) / best_cycles
        self.logger.debug('Ops/Cycle: {:,.2f}'.format(ops_per_cycle))
        ops_per_cycle_per_pe = float(ops_per_cycle) / (self.accelerator.N * self.accelerator.M)
        self.logger.debug('Ops/Cycle/PE: {:,.4}'.format(ops_per_cycle_per_pe))

        return stats, best_instructions

    def get_cycles(self, layer, batch_size=1):
        if isinstance(layer, ConvLayer):
            return self.get_conv_cycles(layer.sfil,  # K
                                        layer.hofm,  # Oh == Ow
                                        layer.htrd,  # S
                                        layer.nifm,  # NI
                                        layer.nofm,  # NO
                                        layer.iprec,  # Activation Precision
                                        layer.wprec,  # Weight Precision
                                        batch_size, # Batch Size
                                        im2col=layer.im2col)  # Batch Size
