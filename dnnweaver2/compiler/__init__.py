from dnnweaver2.tensorOps.cnn import *
from dnnweaver2.graph import Graph
from dnnweaver2.tensor import Tensor

from dnnweaver2.optimizer.optimizer import optimize_for_order, get_stats_fast
from dnnweaver2.isa import *
from dnnweaver2.isa import ScratchPad, AccessType

from collections import OrderedDict, namedtuple
import numpy as np

import os
import math

import logging

from dnnweaver2.compiler.pu_compiler import PUCompiler

InstructionBlock = namedtuple('InstructionBlock', ['Op_name', 'Instructions'])

class FPGASpec(object):
    def __init__(self, num_ddr=1, size_ddr=2**32, bandwidth_per_ddr=512):
        assert num_ddr > 0
        assert size_ddr > 0
        assert bandwidth_per_ddr > 0
        self.num_ddr = num_ddr
        self.size_ddr = size_ddr
        self.bandwidth_per_ddr = bandwidth_per_ddr

class FPGAMemoryManager(object):
    def __init__(self, fpga_spec=None, log_level=logging.INFO):
        # assert isinstance(fpga_spec, FPGASpec)
        # self.fpga_spec = fpga_spec
        # self.size_ddr = self.fpga_spec.size_ddr
        self.curr_ddr_ptr = 0
        self.log = logging.getLogger('FPGA memory manager')
        self.log.setLevel(log_level)

    def alloc(self, tensor):
        assert isinstance(tensor, Tensor)
        if tensor.fpga_addr is None:
            tensor.fpga_addr = self.curr_ddr_ptr
            self.log.debug('Assigned address {}:{} to tensor {}'.format(self.curr_ddr_ptr, self.curr_ddr_ptr+tensor.fpga_size_in_bytes, tensor))
            self.curr_ddr_ptr += 4*int(math.ceil(tensor.fpga_size_in_bytes / 1024.) * 1024) + 1024 * np.random.randint(1, 16)

class MacroNode(object):
    def __init__(self, op):
        assert isinstance(op, Convolution)
        self.sys_array_op = op
        self.pu_op = []
        self.name = op.name
    def append(self, op):
        assert isinstance(op, MaxPooling) or isinstance(op, LeakyReLU) or isinstance(op, BatchNorm) or isinstance(op, TypeCastOp)
        self.pu_op.append(op)
        self.name = '{}+{}'.format(self.name, op.name)

class GraphCompiler(object):

    def __init__(self, fpga_spec=None, log_level=logging.INFO):
        self.log = logging.getLogger('Graph Compiler')
        self.log.setLevel(log_level)
        self.fpga_spec = fpga_spec
        if self.fpga_spec is not None:
            assert isinstance(self.fpga_spec, FPGASpec)
            self.fpga_manager = FPGAMemoryManager(self.fpga_spec, log_level=log_level)
        else:
            self.fpga_sepc = FPGASpec()
            self.fpga_manager = FPGAMemoryManager(self.fpga_spec, log_level=log_level)
        self.pu_compiler = PUCompiler(self.fpga_manager, log_level=self.log.level)
        self.conv_tiling = OrderedDict()

    def optimize_tiling(self, op, graph, acc_obj, pool_kernel=None, pool_stride=None):
        K = op.weights.fpga_shape[-2]
        O = op.output_tensors.fpga_shape[-2]
        S = op.stride[-1]
        IC = op.weights.fpga_shape[-1]
        OC = op.weights.fpga_shape[-4]
        iprec = 16
        wprec = 16
        B = op.data.fpga_shape[-4]
        im2col = False

        # set energy cost to 0 since this version of the compiler is optimized for performance
        energy_cost = (0,0,0,0,0,0,0,0,0,0)
        conv_params = (acc_obj, K, O, S, IC, OC, B, iprec, wprec, im2col, energy_cost)
        tiling, order, _, _ = optimize_for_order(conv_params, sequential=False, pool_kernel=pool_kernel, pool_stride=pool_stride)

        conv_params_with_pool = (acc_obj, K, O, S, IC, OC, B, iprec, wprec, im2col, energy_cost, pool_kernel, pool_stride)

        # Convert tiling and order to an ordered dict
        best_tiling = OrderedDict()
        for o in order:
            best_tiling[o] = tiling[o]

        # We don't tile the KH/KW loops
        best_tiling['KH/kh'] = (1, K)
        best_tiling['KW/kw'] = (1, K)
        return best_tiling

    def _alloc_tensor(self, graph):
        for tname, t in graph.tensor_registry.items():
            if isinstance(t, Tensor):
                self.fpga_manager.alloc(t)

    def _conv_compile(self, conv_op, pu_op, tiling, array_n, array_m, last=False):
        """
        Compiler for convolution layers
        TODO: replace hard-coded array sizes
        """
        inst_array = []
        inst_array.append(SetupInstruction(16, 16).get_binary())

        self.log.debug('Convolution op: {}'.format(conv_op.name))

        pool_pad = ((0,0), (0,0), (0,0), (0,0))
        for op in pu_op:
            self.log.debug('PU Op: {}'.format(op.name))
            if isinstance(op, MaxPooling):
                pool_pad = op.pad

        pool_pad_h_t = pool_pad[1][0]
        pool_pad_h_b = pool_pad[1][1]
        pool_pad_w_l = pool_pad[2][0]
        pool_pad_w_r = pool_pad[2][1]
        pool_pad_h = pool_pad_h_t + pool_pad_h_b
        pool_pad_w = pool_pad_w_l + pool_pad_w_r

        inst_array.append(BaseAddressInstruction(ScratchPad.IBUF, 0, conv_op.data.fpga_addr).get_binary())
        inst_array.append(BaseAddressInstruction(ScratchPad.WBUF, 0, conv_op.weights.fpga_addr).get_binary())
        inst_array.append(BaseAddressInstruction(ScratchPad.BIAS, 0, conv_op.bias.fpga_addr).get_binary())
        inst_array.append(BaseAddressInstruction(ScratchPad.OBUF, 0, conv_op.output_tensors.fpga_addr).get_binary())

        inst_array.append(BaseAddressInstruction(ScratchPad.IBUF, 1, conv_op.data.fpga_addr).get_binary())
        inst_array.append(BaseAddressInstruction(ScratchPad.WBUF, 1, conv_op.weights.fpga_addr).get_binary())
        inst_array.append(BaseAddressInstruction(ScratchPad.BIAS, 1, conv_op.bias.fpga_addr).get_binary())
        inst_array.append(BaseAddressInstruction(ScratchPad.OBUF, 1, conv_op.output_tensors.fpga_addr).get_binary())

        # Parallelize loops IC/ic and OC/oc
        tiling['IC/ic'] = (tiling['IC/ic'][0], int(math.ceil(tiling['IC/ic'][1]/float(array_n))))
        tiling['OC/oc'] = (tiling['OC/oc'][0], int(math.ceil(tiling['OC/oc'][1]/float(array_m))))

        b = tiling['B/b'][1]
        ic = tiling['IC/ic'][1]
        oc = tiling['OC/oc'][1]
        oh = tiling['OH/oh'][1]
        ow = tiling['OW/ow'][1]
        kh = tiling['KH/kh'][1]
        kw = tiling['KW/kw'][1]

        inner_loop_tiling = {
                'B/b': b,
                'IC/ic': ic,
                'OC/oc': oc,
                'OH/oh': oh - pool_pad_h,
                'OW/ow': ow - pool_pad_w,
                'KH/kh': kh,
                'KW/kw': kw
                }

        outer_loop_strides = {

            'IC/ic': {
                ScratchPad.IBUF: (3, ic),
                ScratchPad.OBUF: (0, 0),
                ScratchPad.WBUF: (3, ic),
                ScratchPad.BIAS: (0, 0),
            },

            'OC/oc': {
                ScratchPad.IBUF: (0, 0),
                ScratchPad.OBUF: (3, oc),
                ScratchPad.WBUF: (0, oc),
                ScratchPad.BIAS: (0, oc),
            },

            'B/b': {
                ScratchPad.IBUF: (0, b),
                ScratchPad.OBUF: (0, 1),
                ScratchPad.WBUF: (0, 0),
                ScratchPad.BIAS: (0, 0),
            },

            'OH/oh': {
                ScratchPad.IBUF: (1, oh),
                ScratchPad.OBUF: (1, oh),
                ScratchPad.WBUF: (0, 0),
                ScratchPad.BIAS: (0, 0),
            },

            'OW/ow': {
                ScratchPad.IBUF: (2, ow),
                ScratchPad.OBUF: (2, ow),
                ScratchPad.WBUF: (0, 0),
                ScratchPad.BIAS: (0, 0),
            },

            'KH/kh': {
                ScratchPad.IBUF: (1, kh),
                ScratchPad.OBUF: (0, 0),
                ScratchPad.WBUF: (1, kh),
                ScratchPad.BIAS: (0, 0),
            },

            'KW/kw': {
                ScratchPad.IBUF: (2, kw),
                ScratchPad.OBUF: (0, 0),
                ScratchPad.WBUF: (2, kw),
                ScratchPad.BIAS: (0, 0),
            }
        }

        tensor_mapping = {
            ScratchPad.IBUF: conv_op.data,
            ScratchPad.OBUF: conv_op.output_tensors,
            ScratchPad.WBUF: conv_op.weights,
            ScratchPad.BIAS: conv_op.bias
        }

        tensor_tile_shape = {
            ScratchPad.IBUF: (conv_op.data.fpga_shape[0],
                              conv_op.data.fpga_shape[1],
                              conv_op.data.fpga_shape[2],
                              int(math.ceil(conv_op.data.fpga_shape[3]/float(array_n))),
                              array_n),
            ScratchPad.OBUF: (conv_op.output_tensors.fpga_shape[0],
                              conv_op.output_tensors.fpga_shape[1],
                              conv_op.output_tensors.fpga_shape[2],
                              int(math.ceil(conv_op.output_tensors.fpga_shape[3]/float(array_n))), array_m),
            ScratchPad.WBUF: (int(math.ceil(conv_op.weights.fpga_shape[0]/float(array_n))),
                              conv_op.weights.fpga_shape[1],
                              conv_op.weights.fpga_shape[2],
                              int(math.ceil(conv_op.weights.fpga_shape[3]/float(array_n))), array_n, array_m),
            ScratchPad.BIAS: (int(math.ceil(conv_op.bias.fpga_shape[0]/float(array_n))),
                              array_n)
        }

        #outer_loops
        num_outer_loops = 0
        for l, it in tiling.items():
            if it[0] > 1:
                inst_array.append(LoopInstruction(16, 16, it[0]-1).get_binary())
                for buf, s in outer_loop_strides[l].items():
                    dim, dim_stride = s
                    tensor = tensor_mapping[buf]
                    shape = tensor_tile_shape[buf]
                    stride = (np.prod(shape[dim+1:]) * dim_stride * tensor.dtype.bits) / 8
                    if stride >= (1<<16):
                        inst_array.append(GenAddrHighInstruction(buf, AccessType.LD, 16, stride).get_binary())
                    inst_array.append(GenAddrLowInstruction(buf, AccessType.LD, 16, stride).get_binary())
                    if tensor.op == conv_op:
                        if stride >= (1<<16):
                            inst_array.append(GenAddrHighInstruction(buf, AccessType.ST, 16, stride).get_binary())
                        inst_array.append(GenAddrLowInstruction(buf, AccessType.ST, 16, stride).get_binary())

                num_outer_loops += 1

        if num_outer_loops == 0:
            inst_array.append(LoopInstruction(16, 16, 0).get_binary())
            for buf, s in outer_loop_strides[l].items():
                tensor = tensor_mapping[buf]
                inst_array.append(GenAddrLowInstruction(buf, AccessType.LD, 16, 0).get_binary())
                if tensor.op == conv_op:
                    inst_array.append(GenAddrLowInstruction(buf, AccessType.ST, 16, 0).get_binary())

        ih = (oh - 1) * conv_op.stride[-2] + kh
        iw = (ow - 1) * conv_op.stride[-1] + kw

        assert pool_pad_h_t == 0
        assert pool_pad_w_l == 0

        padded_tile_shape_mapping = {
            ScratchPad.IBUF: (b,ih,iw,ic),
            ScratchPad.OBUF: (b,oh,ow,oc),
            ScratchPad.WBUF: (oc,kh,kw,ic),
            ScratchPad.BIAS: (oc,)
        }

        #memory_access_loops
        for buf, tile_shape in padded_tile_shape_mapping.items():
            num_loops = 0
            tensor = tensor_mapping[buf]
            inst_array.append(LDMemInstruction(buf, tensor.dtype.bits//8, buf+1, 1).get_binary())
            if buf == 1:
                inst_array.append(STMemInstruction(buf, tensor.dtype.bits//8, buf+1, 1).get_binary())
            shape = tensor_tile_shape[buf]
            for dim in reversed(range(len(tile_shape))):
                s = tile_shape[dim]
                if s > 1:
                    stride = (np.prod(shape[dim+1:]) * 1 * tensor.dtype.bits) / 8
                    inst_array.append(LoopInstruction(buf+1, buf+1, s-1).get_binary())
                    if stride >= (1<<16):
                        inst_array.append(GenAddrHighInstruction(buf, AccessType.LD, buf+1, stride).get_binary())
                    inst_array.append(GenAddrLowInstruction(buf, AccessType.LD, buf+1, stride).get_binary())
                    if buf == 1:
                        if stride >= (1<<16):
                            inst_array.append(GenAddrHighInstruction(buf, AccessType.ST, buf+1, stride).get_binary())
                        inst_array.append(GenAddrLowInstruction(buf, AccessType.ST, buf+1, stride).get_binary())
                    num_loops += 1
            if num_loops == 0:
                inst_array.append(LoopInstruction(buf+1, buf+1, 0).get_binary())
                inst_array.append(GenAddrLowInstruction(buf, AccessType.LD, buf+1, 0).get_binary())
                if buf == 1:
                    inst_array.append(GenAddrLowInstruction(buf, AccessType.ST, buf+1, 0).get_binary())

        inner_loop_strides = {
            'IC/ic': {
                ScratchPad.IBUF: (3, 1),
                ScratchPad.OBUF: (0, 0),
                ScratchPad.WBUF: (3, 1),
                ScratchPad.BIAS: (0, 0),
            },
            'OC/oc': {
                ScratchPad.IBUF: (0, 0),
                ScratchPad.OBUF: (3, 1),
                ScratchPad.WBUF: (0, 1),
                ScratchPad.BIAS: (0, 1),
            },
            'B/b': {
                ScratchPad.IBUF: (0, 1),
                ScratchPad.OBUF: (0, 1),
                ScratchPad.WBUF: (0, 0),
                ScratchPad.BIAS: (0, 0),
            },
            'OH/oh': {
                ScratchPad.IBUF: (1, 1),
                ScratchPad.OBUF: (1, 1),
                ScratchPad.WBUF: (0, 0),
                ScratchPad.BIAS: (0, 0),
            },
            'OW/ow': {
                ScratchPad.IBUF: (2, 1),
                ScratchPad.OBUF: (2, 1),
                ScratchPad.WBUF: (0, 0),
                ScratchPad.BIAS: (0, 0),
            },
            'KH/kh': {
                ScratchPad.IBUF: (1, 1),
                ScratchPad.OBUF: (0, 0),
                ScratchPad.WBUF: (1, 1),
                ScratchPad.BIAS: (0, 0),
            },
            'KW/kw': {
                ScratchPad.IBUF: (2, 1),
                ScratchPad.OBUF: (0, 0),
                ScratchPad.WBUF: (2, 1),
                ScratchPad.BIAS: (0, 0),
            }
        }

        inner_loop_order = ('IC/ic', 'KW/kw', 'KH/kh', 'OW/ow', 'OH/oh', 'OC/oc', 'B/b')

        #inner_loops
        num_inner_loops = 0
        for l in inner_loop_order:
            it = inner_loop_tiling[l]

            if it > 1:
                inst_array.append(LoopInstruction(0, 0, it-1).get_binary())
                for buf, s in inner_loop_strides[l].items():
                    dim, dim_stride = s
                    tensor = tensor_mapping[buf]
                    tile_shape = padded_tile_shape_mapping[buf]
                    stride = np.prod(tile_shape[dim+1:]) * dim_stride
                    if stride >= (1<<16):
                        raise ValueError('stride for inner loop is too high: {}'.format(stride))
                        # inst_array.append(GenAddrHighInstruction(buf, AccessType.RD, 0, stride).get_binary())
                    inst_array.append(GenAddrLowInstruction(buf, AccessType.RD, 0, stride).get_binary())
                    if tensor.op == conv_op:
                        inst_array.append(GenAddrLowInstruction(buf, AccessType.WR, 0, stride).get_binary())
                        if stride >= (1<<16):
                            raise ValueError('stride for inner loop is too high: {}'.format(stride))
                            # inst_array.append(GenAddrHighInstruction(buf, AccessType.WR, 0, stride).get_binary())
                num_inner_loops += 1

        if num_inner_loops == 0:
            inst_array.append(LoopInstruction(0, 0, 0).get_binary())
            inst_array.append(GenAddrLowInstruction(ScratchPad.IBUF, AccessType.RD, 0, 0).get_binary())
            inst_array.append(GenAddrLowInstruction(ScratchPad.WBUF, AccessType.RD, 0, 0).get_binary())
            inst_array.append(GenAddrLowInstruction(ScratchPad.OBUF, AccessType.WR, 0, 0).get_binary())
            inst_array.append(GenAddrLowInstruction(ScratchPad.OBUF, AccessType.RD, 0, 0).get_binary())
            inst_array.append(GenAddrLowInstruction(ScratchPad.BIAS, AccessType.RD, 0, 0).get_binary())

        # PU operations now
        pu_inst = self.pu_compiler.compile_layer(tiling, conv_op.output_tensors, pu_op, simd_lanes=array_m)
        for i in pu_inst:
            inst_array.append(i)
        inst_array.append(BlockEndInstruction(last).get_binary())

        return inst_array

    def compile_macro_node(self, graph, acc_obj):
        pass

    def compile(self, graph, acc_obj):

        array_n, array_m = acc_obj.N, acc_obj.M
        assert isinstance(graph, Graph)
        inst_binary = []

        self.log.debug('#'*50)
        self.log.debug('Combining graph ops to create macro op')
        macro_node_array = []
        curr_node = None
        for opname, op in graph.op_registry.items():
            self.log.debug('\t{}'.format(opname))
            if isinstance(op, Convolution):
                if curr_node is None:
                    curr_node = MacroNode(op)
                else:
                    macro_node_array.append(curr_node)
                    curr_node = MacroNode(op)
            else:
                assert curr_node is not None
                curr_node.append(op)
        assert curr_node is not None
        macro_node_array.append(curr_node)
        self.log.debug('Combining graph ops to create macro op - done!')

        for i in range(len(macro_node_array)):
            macro_node = macro_node_array[i]
            conv_pad = list(macro_node.sys_array_op.pad)

            # We pad the input channels to be a multiple of number of rows
            ic = macro_node.sys_array_op.data.shape[-1]
            ic_padded = int(math.ceil(ic/float(array_n))*array_n)
            ic_padding = ic_padded - ic
            conv_pad[-1] = (0,ic_padding)
            macro_node.sys_array_op.data.fpga_pad = tuple(conv_pad)

            # We pad the output channels to be a multiple of number of columns
            oc = macro_node.sys_array_op.weights.shape[-4]
            oc_padded = int(math.ceil(oc/float(array_m))*array_m)
            oc_padding = oc_padded - oc
            weights_pad = ((0,oc_padding), (0,0), (0,0), (0,ic_padding))

            bias_pad = ((0,oc_padding))

            macro_node.sys_array_op.weights.fpga_pad = ((0,oc_padding), (0,0), (0,0), (0, ic_padding))

            conv_out_pad = ((0,0), (0,0), (0,0), (0,oc_padding))
            for op in macro_node.pu_op:
                if isinstance(op, MaxPooling):
                    conv_out_pad = list(op.pad)
                    conv_out_pad[-1] = (conv_out_pad[-1][0], conv_out_pad[-1][1]+oc_padding)
                    conv_out_pad = tuple(conv_out_pad)
            macro_node.sys_array_op.output_tensors.fpga_pad = conv_out_pad

            # TODO: verify if this is correct
            pool_out_pad = ((0,0),(0,0),(0,0),(0,oc_padding))
            macro_node.pu_op[-1].output_tensors.fpga_pad = pool_out_pad

        self.log.debug('#'*50)
        for i in range(len(macro_node_array)):
            macro_node = macro_node_array[i]
            self.log.debug('#'*50)
            self.log.debug('Compiling macro op: {}'.format(macro_node.name))
            self.log.debug('\tConvolution op: {}'.format(macro_node.sys_array_op.name))
            self.log.debug('\tOther ops:')
            for op in macro_node.pu_op:
                self.log.debug('\t\t{}'.format(op.name))

            self.log.debug('Optimizing tiling for Convolution layer {}'.format(macro_node.sys_array_op.name))
            pool_stride = None
            pool_kernel = None
            for op in macro_node.pu_op:
                if isinstance(op, MaxPooling):
                    pool_pad = op.pad
                    pool_stride = op.stride
                    pool_kernel = op.pooling_kernel
            optimal_tiling = self.optimize_tiling(macro_node.sys_array_op, graph, acc_obj, pool_stride=pool_stride, pool_kernel=pool_kernel)
            self.conv_tiling[macro_node.sys_array_op] = optimal_tiling
            self.log.debug('Optimal tiling and ordering:')
            indent = 1
            for loop, tile in optimal_tiling.items():
                self.log.debug('{}Loop: {:>6}, Tile: {}'.format(indent * '==', loop, tile))
                indent += 1

            last = i == len(macro_node_array) - 1
            self.log.debug('Allocating tensors for macro op: {}'.format(macro_node.name))
            self._alloc_tensor(graph)
            inst_array = self._conv_compile(conv_op=macro_node.sys_array_op, pu_op=macro_node.pu_op, tiling=optimal_tiling, array_n=array_n, array_m=array_m, last=last)
            inst_binary.append(InstructionBlock(macro_node, inst_array))
            self.log.debug('#'*50)

        self.log.debug('Compiling macro ops - done!')

        inst_array = []
        for i in inst_binary:
            inst = i.Instructions
            op_name = i.Op_name
            for _i in inst:
                inst_array.append(_i)
            # inst_array += inst

        with open('inst.bin', 'w') as f:
            for inst in inst_array:
                f.write('{}'.format(inst))
                f.write('\n')
        return np.array(inst_array, dtype=np.int32)
