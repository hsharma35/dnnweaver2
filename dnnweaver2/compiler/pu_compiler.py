from dnnweaver2.tensorOps.cnn import *
from dnnweaver2.graph import Graph
from dnnweaver2.tensor import Tensor

from dnnweaver2.isa import *

from collections import OrderedDict, namedtuple
import numpy as np

import os
import math
import logging

class PUCompiler(object):

    def __init__(self, fpga_manager, log_level=logging.INFO):
        self.log = logging.getLogger('PU Compiler')
        self.log.setLevel(log_level)
        self.rf_size = 8
        self.rf = np.zeros((self.rf_size,), dtype=np.bool)
        self.fpga_manager = fpga_manager

    def acquire_reg(self):
        for i in range(self.rf_size):
            if self.rf[i] == 0:
                self.rf[i] = 1
                return i
        raise ValueError('No more registers left')

    def release_reg(self, i):
        self.rf[i] = 0

    def compile_layer(self, conv_tiling, conv_out_tensor, pu_ops, simd_lanes=4):
        """
        Compiler for PU layers
        """

        pool_pad = ((0,0), (0,0), (0,0), (0,0))
        for op in pu_ops:
            if isinstance(op, MaxPooling):
                pool_pad = op.pad

        pool_pad_h_t = pool_pad[1][0]
        pool_pad_h_b = pool_pad[1][1]
        pool_pad_w_l = pool_pad[2][0]
        pool_pad_w_r = pool_pad[2][1]
        pool_pad_h = pool_pad_h_t + pool_pad_h_b
        pool_pad_w = pool_pad_w_l + pool_pad_w_r

        if len(pu_ops) > 0:
            self.fpga_manager.alloc(pu_ops[-1].output_tensors)

        for op in pu_ops[:-1]:
            if isinstance(op, BatchNorm):
                self.fpga_manager.alloc(op.mean)
                self.fpga_manager.alloc(op.scale)

        # get tile size
        b  = conv_tiling['B/b'][1]
        oc = conv_tiling['OC/oc'][1]
        oh = conv_tiling['OH/oh'][1]
        ow = conv_tiling['OW/ow'][1]

        # get input tensor size
        B, OH, OW, OC = conv_out_tensor.shape

        # initialize pooled size
        pool_ow, pool_oh = ow, oh
        pool_kw = 1
        pool_kh = 1
        pool_sh = 1
        pool_sw = 1
        P_OW, P_OH = OH, OW
        for op in pu_ops:
            if isinstance(op, MaxPooling):
                P_OW = op.output_tensors.shape[-2]
                P_OH = op.output_tensors.shape[-3]
                pool_kh = op.pooling_kernel[1]
                pool_kw = op.pooling_kernel[2]
                pool_sh = op.stride[1]
                pool_sw = op.stride[2]
                pool_ow = (ow - pool_kw) // pool_sw + 1
                pool_oh = (oh - pool_kh) // pool_sh + 1

        pooled_output_strides = {
                'IC/ic': (0, 1),
                'OC/oc': (3, 1),
                'B/b'  : (0, 1),
                'OH/oh': (1, 1),
                'OW/ow': (2, 1),
                'KH/kh': (0, 0),
                'KW/kw': (0, 0)
            }

        pu_inst_list = [None]

        conv_tile_shape = (b, oh, ow, oc)
        pool_tile_shape = (b, pool_oh, pool_ow, oc)

        pre_pool_ops = []
        pool_op = None
        post_pool_ops = []
        pre_pool = True

        ld0_required = False
        ld1_required = False

        bn_pre_pool = False

        bn_mean_addr = None
        bn_scale_addr = None

        for op in pu_ops:
            if isinstance(op, BatchNorm):
                ld0_required = True
                ld1_required = True
                if pre_pool:
                    bn_pre_pool = True
                bn_mean_addr = op.mean.fpga_addr
                bn_scale_addr = op.scale.fpga_addr
            if isinstance(op, MaxPooling):
                pool_op = op
                pre_pool = False
            else:
                if pre_pool:
                    pre_pool_ops.append(op)
                else:
                    post_pool_ops.append(op)


        if len(pu_ops) > 0:
            t_out = pu_ops[-1].output_tensors
        else:
            t_out = conv_out_tensor

        t_out_addr = t_out.fpga_addr
        pad_offset = 0
        for i in range(len(t_out.shape)):
            pad_offset += t_out.fpga_pad[i][0] * np.prod(t_out.fpga_shape[i+1:])
        pad_offset = int(pad_offset * t_out.dtype.bits / 8)
        t_out_addr += pad_offset

        pu_inst_list.append(BaseAddressInstruction(0,0,0))

        pu_inst_list.append(BaseAddressInstruction(1,0,t_out_addr))
        pu_inst_list.append(BaseAddressInstruction(1,1,t_out_addr))

        if ld0_required:
            pu_inst_list.append(BaseAddressInstruction(2,0,bn_mean_addr))
            pu_inst_list.append(BaseAddressInstruction(2,1,bn_mean_addr))
        if ld1_required:
            pu_inst_list.append(BaseAddressInstruction(3,0,bn_scale_addr))
            pu_inst_list.append(BaseAddressInstruction(3,1,bn_scale_addr))

        pu_inst_list.append(LoopInstruction(0, 0, pool_kw-1))
        pu_inst_list.append(GenAddrLowInstruction(0, 0, 0, oc))
        pu_inst_list.append(LoopInstruction(0, 0, pool_kh-1))
        pu_inst_list.append(GenAddrLowInstruction(0, 0, 0, oc*ow))
        pu_inst_list.append(LoopInstruction(0, 0, pool_ow-1))
        pu_inst_list.append(GenAddrLowInstruction(0, 0, 0, oc*pool_sw))
        pu_inst_list.append(LoopInstruction(0, 0, pool_oh-1))
        pu_inst_list.append(GenAddrLowInstruction(0, 0, 0, oc*pool_sh*ow))
        pu_inst_list.append(LoopInstruction(0, 0, oc-1))
        pu_inst_list.append(GenAddrLowInstruction(0, 0, 0, 1))
        pu_inst_list.append(LoopInstruction(0, 0, b-1))
        pu_inst_list.append(GenAddrLowInstruction(0, 0, 0, oc*oh*ow))

        if ld0_required:
            pu_inst_list.append(LDMemInstruction(2, 32, 0, 0))
        if ld1_required:
            pu_inst_list.append(LDMemInstruction(3, 32, 0, 0))

        _pool_tile = {
            'B/b': b,
            'OC/oc': oc,
            'OH/oh': pool_oh,
            'OW/ow': pool_ow
        }

        base_addr_loops = 0
        for loop, it in conv_tiling.items():
            if it[0] > 1 and loop in _pool_tile:
                if len(pu_ops) > 0:
                    P_B,P_OH,P_OW, P_OC = op.output_tensors.fpga_shape
                else:
                    P_B,P_OH,P_OW, P_OC = conv_out_tensor.fpga_shape
                dim, dim_stride = pooled_output_strides[loop]
                shape = (P_B,P_OH,P_OW,int(math.ceil(float(P_OC)/simd_lanes)))
                pu_inst_list.append(LoopInstruction(5, 5, it[0]-1))
                stride = int(np.prod(shape[dim+1:]) * dim_stride * 2 * simd_lanes) * _pool_tile[loop]
                if stride > (1<<15):
                    pu_inst_list.append(GenAddrHighInstruction(5, 5, 0, stride))
                pu_inst_list.append(GenAddrLowInstruction(5, 5, 0, stride))
                base_addr_loops += 1

                if loop == 'OC/oc' and ld0_required:
                    stride = 2 * simd_lanes * oc
                else:
                    stride = 0
                assert stride < (1<<15)
                pu_inst_list.append(GenAddrLowInstruction(6, 6, 0, stride))
                if loop == 'OC/oc' and ld1_required:
                    stride = 2 * simd_lanes * oc
                else:
                    stride = 0
                assert stride < (1<<15)
                pu_inst_list.append(GenAddrLowInstruction(7, 7, 0, stride))

        if base_addr_loops == 0:
            pu_inst_list.append(LoopInstruction(5, 5, 0))
            pu_inst_list.append(GenAddrLowInstruction(5, 5, 0, 0))
            pu_inst_list.append(GenAddrLowInstruction(6, 6, 0, 0))
            pu_inst_list.append(GenAddrLowInstruction(7, 7, 0, 0))

        if len(pu_ops) > 0:
            P_B, P_OH, P_OW, P_OC = pu_ops[-1].output_tensors.fpga_shape
        else:
            P_B, P_OH, P_OW, P_OC = conv_out_tensor.fpga_shape
        P_OC = int(math.ceil(P_OC / float(simd_lanes)))

        pu_inst_list.append(LoopInstruction(1, 1, pool_ow-1))
        if P_OC > (1<<15):
            pu_inst_list.append(GenAddrHighInstruction(1, 1, 0, P_OC))
        pu_inst_list.append(GenAddrLowInstruction(1, 1, 0, P_OC))
        pu_inst_list.append(LoopInstruction(1, 1, pool_oh-1))
        if P_OC*P_OW > (1<<15):
            pu_inst_list.append(GenAddrHighInstruction(1, 1, 0, P_OC*P_OW))
        pu_inst_list.append(GenAddrLowInstruction(1, 1, 0, P_OC*P_OW))
        pu_inst_list.append(LoopInstruction(1, 1, oc-1))
        pu_inst_list.append(GenAddrLowInstruction(1, 1, 0, 1))
        pu_inst_list.append(LoopInstruction(1, 1, b-1))
        if P_OC*P_OW*P_OH > (1<<15):
            pu_inst_list.append(GenAddrHighInstruction(1, 1, 0, P_OC*P_OW*P_OH))
        pu_inst_list.append(GenAddrLowInstruction(1, 1, 0, P_OC*P_OH*P_OW))


        if ld0_required:
            # if bn_pre_pool:
            #     pu_inst_list.append(LoopInstruction(2, 2, pool_kw-1))
            #     pu_inst_list.append(GenAddrLowInstruction(2, 2, 0, 0))
            #     pu_inst_list.append(LoopInstruction(2, 2, pool_kh-1))
            #     pu_inst_list.append(GenAddrLowInstruction(2, 2, 0, 0))
            pu_inst_list.append(LoopInstruction(2, 2, pool_ow-1))
            pu_inst_list.append(GenAddrLowInstruction(2, 2, 0, 0))
            pu_inst_list.append(LoopInstruction(2, 2, pool_oh-1))
            pu_inst_list.append(GenAddrLowInstruction(2, 2, 0, 0))
            pu_inst_list.append(LoopInstruction(2, 2, oc-1))
            pu_inst_list.append(GenAddrLowInstruction(2, 2, 0, 1))
            pu_inst_list.append(LoopInstruction(2, 2, b-1))
            pu_inst_list.append(GenAddrLowInstruction(2, 2, 0, 0))

        if ld1_required:
            # if bn_pre_pool:
            #     pu_inst_list.append(LoopInstruction(3, 3, pool_kw-1))
            #     pu_inst_list.append(GenAddrLowInstruction(3, 3, 0, 0))
            #     pu_inst_list.append(LoopInstruction(3, 3, pool_kh-1))
            #     pu_inst_list.append(GenAddrLowInstruction(3, 3, 0, 0))
            pu_inst_list.append(LoopInstruction(3, 3, pool_ow-1))
            pu_inst_list.append(GenAddrLowInstruction(3, 3, 0, 0))
            pu_inst_list.append(LoopInstruction(3, 3, pool_oh-1))
            pu_inst_list.append(GenAddrLowInstruction(3, 3, 0, 0))
            pu_inst_list.append(LoopInstruction(3, 3, oc-1))
            pu_inst_list.append(GenAddrLowInstruction(3, 3, 0, 1))
            pu_inst_list.append(LoopInstruction(3, 3, b-1))
            pu_inst_list.append(GenAddrLowInstruction(3, 3, 0, 0))

        compute_instructions = []

        dest_reg = None
        pool_reg = None
        bn_scale_reg = None
        bn_mean_reg = None
        for idx in range(pool_kw * pool_kh):
            if dest_reg is None:
                dest_reg = self.acquire_reg()
                # output_frac_bits = pu_ops[-1].output_tensors.dtype.frac_bits
                # input_frac_bits = conv_out_tensor.dtype.frac_bits
                # bits = input_frac_bits - output_frac_bits
                # compute_instructions.append(ComputeRshiftImm(src0_addr=8, imm=bits, dest_addr=dest_reg))
                compute_instructions.append(ComputeNop(src0_addr=8, dest_addr=dest_reg))

            for op in pre_pool_ops:
                if isinstance(op, LeakyReLU):
                    val = op.scalar.data
                    # assuming 16-bits
                    bits = 16
                    val = int(float(val) * (1<<bits))
                    assert val < (1<<bits) - 1 and val >= -(1<<bits)

                    tmp_reg = self.acquire_reg()
                    compute_instructions.append(ComputeMulImm(src0_addr=dest_reg, imm=val, dest_addr=tmp_reg))
                    compute_instructions.append(ComputeRshiftImm(src0_addr=tmp_reg, imm=bits, dest_addr=tmp_reg))
                    compute_instructions.append(ComputeMax(src0_addr=dest_reg, src1_addr=tmp_reg, dest_addr=dest_reg))
                    self.release_reg(tmp_reg)

                elif isinstance(op, BatchNorm):
                    if bn_scale_reg is None:
                        bn_scale_reg = self.acquire_reg()
                        compute_instructions.append(ComputeNop(src0_addr=9, dest_addr=bn_scale_reg))
                        assert bn_mean_reg is None
                        bn_mean_reg = self.acquire_reg()
                        compute_instructions.append(ComputeNop(src0_addr=10, dest_addr=bn_mean_reg))

                    if isinstance(compute_instructions[-1], ComputeNop) and compute_instructions[-1].dest_addr == dest_reg:
                        src_addr = compute_instructions[-1].src0_addr
                        compute_instructions[-1] = ComputeSub(src0_addr=src_addr, src1_addr=bn_scale_reg, dest_addr=dest_reg)
                    else:
                        compute_instructions.append(ComputeSub(src0_addr=dest_reg, src1_addr=bn_scale_reg, dest_addr=dest_reg))
                    compute_instructions.append(ComputeRshiftImm(src0_addr=dest_reg, imm=0, dest_addr=dest_reg))
                    compute_instructions.append(ComputeMul(src0_addr=dest_reg, src1_addr=bn_mean_reg, dest_addr=dest_reg))

                elif isinstance(op, TypeCastOp):
                    shift = op.data.dtype.frac_bits - op.output_tensors.dtype.frac_bits
                    compute_instructions.append(ComputeRshiftImm(src0_addr=dest_reg, imm=shift, dest_addr=dest_reg))

                else:
                    raise ValueError('Not implemented')

            if pool_reg is None:
                pool_reg = dest_reg
                dest_reg = None

            else:
                assert dest_reg is not None
                assert pool_reg is not None

                if idx != (pool_kw * pool_kh - 1) or len(post_pool_ops) > 0:
                    compute_instructions.append(ComputeMax(src0_addr=dest_reg, src1_addr=pool_reg, dest_addr=pool_reg))
                else:
                    compute_instructions.append(ComputeMax(src0_addr=dest_reg, src1_addr=pool_reg, dest_addr=8))
                    pool_reg = self.release_reg(pool_reg)
                dest_reg = self.release_reg(dest_reg)

        if ld0_required or ld1_required:
            assert bn_scale_reg is not None
            bn_scale_reg = self.release_reg(bn_scale_reg)
            assert bn_mean_reg is not None
            bn_mean_reg = self.release_reg(bn_mean_reg)

        # Post pool ops
        assert dest_reg is None
        dest_reg = pool_reg
        for op in post_pool_ops:
            if isinstance(op, LeakyReLU):
                val = op.scalar.data
                # assuming 16-bits
                bits = 16
                val = int(float(val) * (1<<bits))
                assert val < (1<<bits) - 1 and val >= -(1<<bits)

                tmp_reg = self.acquire_reg()
                compute_instructions.append(ComputeMulImm(src0_addr=dest_reg, imm=val, dest_addr=tmp_reg))
                compute_instructions.append(ComputeRshiftImm(src0_addr=tmp_reg, imm=bits, dest_addr=tmp_reg))
                compute_instructions.append(ComputeMax(src0_addr=dest_reg, src1_addr=tmp_reg, dest_addr=dest_reg))
                self.release_reg(tmp_reg)


            elif isinstance(op, BatchNorm):
                compute_instructions.append(ComputeSub(src0_addr=dest_reg, src1_addr=9, dest_addr=dest_reg))
                compute_instructions.append(ComputeRshiftImm(src0_addr=dest_reg, imm=0, dest_addr=dest_reg))
                compute_instructions.append(ComputeMul(src0_addr=dest_reg, src1_addr=10, dest_addr=dest_reg))

            elif isinstance(op, TypeCastOp):
                shift = op.data.dtype.frac_bits - op.output_tensors.dtype.frac_bits
                compute_instructions.append(ComputeRshiftImm(src0_addr=dest_reg, imm=shift, dest_addr=dest_reg))

            else:
                raise ValueError('Not implemented')

        if dest_reg is not None:
            compute_instructions.append(ComputeNop(src0_addr=dest_reg, dest_addr=8))
            dest_reg = self.release_reg(dest_reg)

        for inst in compute_instructions:
            pu_inst_list.append(inst)


        num_repeats = b * pool_ow * pool_oh * oc
        pu_inst_list.append(PUBlockRepeat(num_repeats))

        for i in self.rf:
            assert i == 0

        inst_array = []
        if len(pu_inst_list) > 1:
            pu_inst_list[0] = PUBlockStart(len(pu_inst_list)-2)
            for i in pu_inst_list:
                inst_array.append(i.get_binary())
            return inst_array
        else:
            return None
