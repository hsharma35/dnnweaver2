from dnnweaver2.utils.utils import ceil_a_by_b, log2
from dnnweaver2.simulator.stats import Stats

class Accelerator(object):
    def __init__(self, N, M, prec, sram, mem_if_width, frequency):
        """
        accelerator object
        """
        self.N = N
        self.M = M
        self.sram = sram
        self.mem_if_width = mem_if_width
        self.frequency = frequency
        self.prec = prec

    def get_mem_read_cycles(self, dst, size):
        """
        Read instruction
        args:
            src_idx: index of source address
            dst: destination address
            size: size of data in bits
        """
        return ceil_a_by_b(size, self.mem_if_width)

    def get_mem_write_cycles(self, src, size):
        """
        Write instruction
        args:
            src_idx: index of source address
            src: destination address
            size: size of data in bits
        """
        return ceil_a_by_b(size, self.mem_if_width)


    def get_compute_stats(self, ic, oc, ow, oh, b, kw, kh, iprec, wprec, im2col=False):
        """
        Compute instruction
        args:
            ic: Input Channels
            oc: Output Channels
            ow: Output Width
            oh: Output Height
            kw: Output Height
            kh: Output Height
            b: Batch Size
            im2col: boolean. If true, we assume the cpu does im2col. Otherwise,
                    we do convolutions channel-wise
        """
        compute_stats = Stats()
        compute_stats.total_cycles = self.get_compute_cycles(ic, oc, ow, oh,
                                                             b, kw, kh,
                                                             iprec,
                                                             wprec,
                                                             im2col)
        return compute_stats


    def get_compute_cycles(self, ic, oc, ow, oh, b, kw, kh, iprec, wprec, im2col=False):
        """
        Compute instruction
        args:
            ic: Input Channels
            oc: Output Channels
            ow: Output Width
            oh: Output Height
            kw: Output Height
            kh: Output Height
            b: Batch Size
            im2col: boolean. If true, we assume the cpu does im2col. Otherwise,
                    we do convolutions channel-wise
        """
        _oc = ceil_a_by_b(oc, self.M)
        _ic = ceil_a_by_b(ic, self.N)

        loops = (b, _oc, oh, ow, kh, kw, _ic)
        loops = sorted(loops, reverse=True)

        overhead = 2
        cycles = 1
        for it in loops:
            cycles = overhead + it * cycles

        return cycles

    def __str__(self):
        ret = ''
        ret += 'Accelerator object'
        ret += '\n'
        ret += '\tPrecision: {}'.format(self.prec)
        ret += '\n'
        ret += '\tSystolic array size: {} -rows x {} -columns'.format(
                self.N,
                self.M)

        ret += '\n'
        ret += '\tIBUF size: {:>10,} Bytes'.format(self.sram['ibuf']//8)
        ret += '\n'
        ret += '\tWBUF size: {:>10,} Bytes'.format(self.sram['wbuf']//8)
        ret += '\n'
        ret += '\tOBUF size: {:>10,} Bytes'.format(self.sram['obuf']//8)
        ret += '\n'
        ret += '\tBBUF size: {:>10,} Bytes'.format(self.sram['bbuf']//8)
        ret += '\n'
        ret += 'Double buffering enabled. Sizes of SRAM are halved'
        return ret
