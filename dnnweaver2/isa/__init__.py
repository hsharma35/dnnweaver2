import math


class OPCodes:
    SETUP       = 0
    LDMEM       = 1
    STMEM       = 2
    RDBUF       = 3
    WRBUF       = 4
    GENADDRHI   = 5
    GENADDRLO   = 6
    LOOP        = 7
    BLOCK_END   = 8
    BASE_ADDR   = 9
    PU_BLOCK    = 10
    COMPUTE_R   = 11
    COMPUTE_I   = 12

class ScratchPad:
    IBUF        = 0
    OBUF        = 1
    WBUF        = 2
    BIAS        = 3

class AccessType:
    LD          = 0
    ST          = 1
    RD          = 2
    WR          = 3

class FNCodes:
    NOP       = 0
    ADD       = 1
    SUB       = 2
    MUL       = 3
    MVHI      = 4
    MAX       = 5
    MIN       = 6
    RSHIFT    = 7


class ComputeInstruction(object):
    def __init__(self, fn, src1_sel, src0_addr, dest_addr, imm=None, src1_addr=None):
        self.fn = fn
        self.src1_sel = src1_sel
        self.src0_addr = src0_addr
        self.dest_addr = dest_addr
        if src1_sel == 1:
            assert imm is not None
            self.op_code = OPCodes.COMPUTE_I
        else:
            assert src1_addr is not None
            self.op_code = OPCodes.COMPUTE_R
        self.imm = imm
        self.src1_addr = src1_addr

    def _src_reg_to_str(self, reg):
        if reg == 8:
            src0 = 'OBUF.pop'
        elif reg == 9:
            src0 = 'LD0.pop'
        elif reg == 10:
            src0 = 'LD1.pop'
        else:
            src0 = 'R{}'.format(reg)
        return src0

    def _dst_reg_to_str(self, reg):
        if reg == 8:
            dest = 'ST-DDR.push'
        else:
            dest = 'R{}'.format(reg)
        return dest

    def _fn_to_str(self, src0, src1, dest):
        if self.fn == FNCodes.NOP:
            fn = '{:<10}     {:<10} -> {:>4}'.format(src0, '', dest)
        elif self.fn == FNCodes.ADD:
            fn = '{:<10} +   {:<10} -> {:>4}'.format(src0, src1, dest)
        elif self.fn == FNCodes.SUB:
            fn = '{:<10} -   {:<10} -> {:>4}'.format(src0, src1, dest)
        elif self.fn == FNCodes.MUL:
            fn = '{:<10} *   {:<10} -> {:>4}'.format(src0, src1, dest)
        elif self.fn == FNCodes.MVHI:
            fn = '{:<10} *   {:<10} -> {:>4}'.format(src1, 1 << 16, dest)
        elif self.fn == FNCodes.MAX:
            fn = '{:<10} max {:<10} -> {:>4}'.format(src0, src1, dest)
        elif self.fn == FNCodes.MIN:
            fn = '{:<10} min {:<10} -> {:>4}'.format(src0, src1, dest)
        else:
            fn = '{:<10} >>  {:<10} -> {:>4}'.format(src0, src1, dest)
        return fn

    def __str__(self):
        src0 = self._src_reg_to_str(self.src0_addr)
        if self.src1_sel == 1:
            src1 = '#({})'.format(self.imm)
        else:
            src1 = self._src_reg_to_str(self.src1_addr)
        dest = self._dst_reg_to_str(self.dest_addr)
        return self._fn_to_str(src0, src1, dest)

    def get_binary(self):
        b = self.dest_addr
        b += self.src0_addr << 4
        if self.src1_sel == 1:
            b += self.imm << 8
            # print(self.imm)
        else:
            b += self.src1_addr << 8
            # print(self.src1_addr)
        # print(b)
        b+= self.fn << 24
        b+= self.src1_sel << 27
        b+= self.op_code << 28
        return b

class ComputeNop(ComputeInstruction):
    def __init__(self, src0_addr, dest_addr):
        fn = FNCodes.NOP
        src1_addr = 0
        super(ComputeNop, self).__init__(fn, 0, src0_addr, dest_addr, imm=None, src1_addr=src1_addr)

class ComputeAdd(ComputeInstruction):
    def __init__(self, src0_addr, src1_addr, dest_addr):
        fn = FNCodes.ADD
        super(ComputeAdd, self).__init__(fn, 0, src0_addr, dest_addr, imm=None, src1_addr=src1_addr)

class ComputeSub(ComputeInstruction):
    def __init__(self, src0_addr, src1_addr, dest_addr):
        fn = FNCodes.SUB
        super(ComputeSub, self).__init__(fn, 0, src0_addr, dest_addr, imm=None, src1_addr=src1_addr)

class ComputeMul(ComputeInstruction):
    def __init__(self, src0_addr, src1_addr, dest_addr):
        fn = FNCodes.MUL
        super(ComputeMul, self).__init__(fn, 0, src0_addr, dest_addr, imm=None, src1_addr=src1_addr)

class ComputeMax(ComputeInstruction):
    def __init__(self, src0_addr, src1_addr, dest_addr):
        fn = FNCodes.MAX
        super(ComputeMax, self).__init__(fn, 0, src0_addr, dest_addr, imm=None, src1_addr=src1_addr)

class ComputeMulImm(ComputeInstruction):
    def __init__(self, src0_addr, imm, dest_addr):
        fn = FNCodes.MUL
        super(ComputeMulImm, self).__init__(fn, 1, src0_addr, dest_addr, imm=imm, src1_addr=None)

class ComputeRshiftImm(ComputeInstruction):
    def __init__(self, src0_addr, imm, dest_addr):
        fn = FNCodes.RSHIFT
        super(ComputeRshiftImm, self).__init__(fn, 1, src0_addr, dest_addr, imm=imm, src1_addr=None)

class ComputeRshift(ComputeInstruction):
    def __init__(self, src0_addr, src1_addr, dest_addr):
        fn = FNCodes.RSHIFT
        super(ComputeRshift, self).__init__(fn, 0, src0_addr, dest_addr, imm=None, src1_addr=src1_addr)

class BFInstruction(object):

    def __init__(self, op_code, op_spec, loop_id, immediate):
        self.op_code = op_code
        self.op_spec = op_spec
        self.loop_id = loop_id
        self.immediate = immediate

    def get_binary(self):
        assert self.op_code   >= 0 and self.op_code   < (1 << 5)
        assert self.op_spec   >= 0 and self.op_spec   < (1 << 6)
        assert self.loop_id   >= 0 and self.loop_id   < (1 << 5)
        assert self.immediate >= 0 and self.immediate < (1 << 16)
        binary = self.op_code << 28
        binary+= self.op_spec << 21
        binary+= self.loop_id << 16
        binary+= self.immediate
        return binary

class PUBlockStart(BFInstruction):
    def __init__(self, num_instructions):
        BFInstruction.__init__(self, OPCodes.PU_BLOCK, 0, 0, num_instructions)

class BaseAddressInstruction(BFInstruction):

    def __init__(self, scratchpad_ID, index, address):
        # print('Scratchpad: {}; address: {}'.format(scratchpad_ID, address))
        self.scratchpad_ID = scratchpad_ID
        self.index = index
        self.address = address
        addr_index = (address >> (index*21))
        immediate = addr_index % (1 << 21)
        loop_id = addr_index >> 16
        op_spec = self.scratchpad_ID << 3
        op_spec += self.index
        BFInstruction.__init__(self, OPCodes.BASE_ADDR, op_spec, 0, immediate)

    def get_binary(self):
        self.op_spec = (self.scratchpad_ID << 3) + self.index
        addr_index = (self.address >> (self.index*21))
        # print('address binary: {}'.format(addr_index))
        self.immediate = addr_index % (1 << 16)
        self.loop_id = (addr_index >> 16) % (1 << 5)
        return super(BaseAddressInstruction, self).get_binary()

class LoopInstruction(BFInstruction):

    def __init__(self, loop_level, loop_id, loop_iterations):
        BFInstruction.__init__(self, OPCodes.LOOP, loop_level, loop_id, loop_iterations)

    def get_binary(self):
        # print('{0},{1}; Loop: 1 -> {2}'.format(self.op_spec, self.loop_id, self.immediate+1))
        return super(LoopInstruction, self).get_binary()

class AccessInstruction(BFInstruction):

    def __init__(self, access_type, scratchpad_ID, mem_bitwidth, loop_id, access_size):
        self.scratchpad_ID = scratchpad_ID
        self.mem_bitwidth = int(math.log(mem_bitwidth) / math.log(2))
        op_spec = self.scratchpad_ID << 3
        op_spec += self.mem_bitwidth << 0
        if access_type == AccessType.LD:
            op_code = OPCodes.LDMEM
        elif access_type == AccessType.ST:
            op_code = OPCodes.STMEM
        elif access_type == AccessType.RD:
            op_code = OPCodes.RDBUF
        elif access_type == AccessType.WR:
            op_code = OPCodes.WRBUF
        else:
            raise Exception('Expected Access type in range {0, 1, 2, 3}')
        BFInstruction.__init__(self, op_code, op_spec, loop_id, access_size)

    def get_binary(self):
        op_spec = self.scratchpad_ID << 3
        op_spec += self.mem_bitwidth << 0
        self.op_spec = op_spec
        return super(AccessInstruction, self).get_binary()

class LDMemInstruction(AccessInstruction):

    def __init__(self, scratchpad_ID, mem_bitwidth, loop_id, access_size):
        # print('====== LD Scratchpad {}, loop: {}, size: {}'.format(scratchpad_ID, loop_id, access_size))
        AccessInstruction.__init__(self, AccessType.LD, scratchpad_ID, mem_bitwidth, loop_id, access_size)

class STMemInstruction(AccessInstruction):

    def __init__(self, scratchpad_ID, mem_bitwidth, loop_id, access_size):
        # print('====== ST Scratchpad {}, loop: {}, size: {}'.format(scratchpad_ID, loop_id, access_size))
        AccessInstruction.__init__(self, AccessType.ST, scratchpad_ID, mem_bitwidth, loop_id, access_size)

class RDBufInstruction(AccessInstruction):

    def __init__(self, scratchpad_ID, mem_bitwidth, loop_id, access_size):
        AccessInstruction.__init__(self, AccessType.RD, scratchpad_ID, mem_bitwidth, loop_id, access_size)

class WRBufInstruction(AccessInstruction):

    def __init__(self, scratchpad_ID, mem_bitwidth, loop_id, access_size):
        AccessInstruction.__init__(self, AccessType.WR, scratchpad_ID, mem_bitwidth, loop_id, access_size)

class SetupInstruction(BFInstruction):

    def __init__(self, op0_bitwidth, op1_bitwidth):
        self.op0_bitwidth = op0_bitwidth
        self.op1_bitwidth = op1_bitwidth
        self.op0_bitwidth_spec = int(math.log(op0_bitwidth) / math.log(2))
        self.op1_bitwidth_spec = int(math.log(op1_bitwidth) / math.log(2))
        op_spec = self.op0_bitwidth_spec << 3
        op_spec += self.op1_bitwidth_spec << 0
        BFInstruction.__init__(self, OPCodes.SETUP, op_spec, 0, 0)

    def get_binary(self):
        op_spec = self.op0_bitwidth_spec << 3
        op_spec += self.op1_bitwidth_spec << 0
        self.op_spec = op_spec
        return super(SetupInstruction, self).get_binary()

class BlockEndInstruction(BFInstruction):

    def __init__(self, last=False):
        last = int(last)
        BFInstruction.__init__(self, OPCodes.BLOCK_END, 0, 0, last)

class PUBlockRepeat(BlockEndInstruction):
    def __init__(self, repeat):
        BlockEndInstruction.__init__(self, repeat-1)

class GenAddrLowInstruction(BFInstruction):

    def __init__(self, scratchpad_ID, ld_st, loop_id, immediate):
        self.scratchpad_ID = scratchpad_ID
        self.ld_st = ld_st
        immediate = int(immediate)
        op_spec = self.scratchpad_ID << 3
        op_spec += self.ld_st << 0
        immediate = immediate % (1<<16)
        # print('Scratchpad {}, ldst: {}, loop_id: {}, stride: {}'.format(scratchpad_ID, ld_st, loop_id, immediate))
        BFInstruction.__init__(self, OPCodes.GENADDRLO, op_spec, loop_id, immediate)

    def get_binary(self):
        op_spec = self.scratchpad_ID << 3
        op_spec += self.ld_st << 0
        self.op_spec = op_spec
        return super(GenAddrLowInstruction, self).get_binary()

class GenAddrHighInstruction(BFInstruction):

    def __init__(self, scratchpad_ID, ld_st, loop_id, immediate):
        self.scratchpad_ID = scratchpad_ID
        self.ld_st = ld_st
        immediate = int(immediate)
        op_spec = self.scratchpad_ID << 3
        op_spec += self.ld_st << 0
        immediate = immediate >> 16
        # print('Scratchpad {}, ldst: {}, loop_id: {}, stride: {}'.format(scratchpad_ID, ld_st, loop_id, immediate))
        BFInstruction.__init__(self, OPCodes.GENADDRHI, op_spec, loop_id, immediate)

    def get_binary(self):
        op_spec = self.scratchpad_ID << 3
        op_spec += self.ld_st << 0
        self.op_spec = op_spec
        return super(GenAddrHighInstruction, self).get_binary()
