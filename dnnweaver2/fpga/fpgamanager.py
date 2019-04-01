import sys
import logging
import numpy as np
import itertools
import array
import math
from time import time, sleep

from dnnweaver2.fpga.memspace import FPGAMemSpace
from dnnweaver2.tensorOps.cnn import Convolution, BatchNorm


def ddr_to_np_array(ddr, start, end, dtype):
    return np.array(array.array(get_dtype_str(dtype), ddr[start:end].tobytes()))

def ceilAByB(a, b):
    return int(math.ceil(a / float(b)))

def _pad_tensor(t, pad_value=0):
    return np.pad(t.data, t.fpga_pad, 'constant', constant_values=(pad_value, pad_value))

def data_transform(arr, idx_list, stride_list, verbose=False):
#    t1 = time()
    arr_size = arr.size
    shape = arr.shape
    arr = arr.flatten()
#    t2 = time()
    ddr_arr = np.empty(arr_size, dtype=arr.dtype)
#    t3 = time()
    stride_list = np.array(stride_list)
#    t4 = time()
    ddr_idx = 0
#    dot_sum = 0.0
#    rest_sum = 0.0
    for indices in itertools.product(*[range(x) for x in idx_list]):
#        t4_1 = time()
        input_idx = np.dot(stride_list, indices)
#        t4_2 = time()
#        dot_sum += t4_2 - t4_1
        if verbose:
            print(stride_list, indices, input_idx, arr[input_idx])
        ddr_arr[ddr_idx] = arr[input_idx]
        ddr_idx += 1
#        t4_3 = time()
#        rest_sum = t4_3 - t4_2
#    t5 = time()
#    string = "data_transform time: %.4f %.4f %.4f %.4f %.4f %.4f" % ((t2-t1), (t3-t2), (t4-t3), (t5-t4), dot_sum, rest_sum)
#    sys.stdout.write("\r" + str(string) + "\n")
#    sys.stdout.flush()

    # ddr_arr = ddr_arr.reshape(shape)
    if verbose:
        print(ddr_arr.flatten().reshape(ddr_arr.size/4,4))
    return ddr_arr

def np_array_to_ddr(arr, idx_list, stride_list, verbose=False):
#    t1 = time()
    ddr_arr = data_transform(arr, idx_list, stride_list, verbose).flatten()
#    _tin_ddr = np.transpose(padded_data.reshape(tin.fpga_size), (0,3,1,2))
#    print (_tin_ddr.shape)
#    if (tin_ddr - _tin_ddr).sum() != 0:
#        print ("DIFF")
#    else:
#        print ("SAME")
#    sys.exit()

#    t2 = time()
#    dtype_str = get_dtype_str(np.int8)
#    t3 = time()
#    string = "np_array_to_ddr time: %.4f %.4f" % ((t2-t1), (t3-t2))
#    sys.stdout.write("\r" + str(string) + "\n")
#    sys.stdout.flush()
#    return np.array(array.array(dtype_str, ddr_arr.tobytes()), dtype=np.int8)
    return ddr_arr

def get_dtype_str(dtype):
    if dtype == np.int8:
        dtype_str = 'B'
    elif dtype == np.int16:
        dtype_str = 'h'
    elif dtype == np.int32:
        dtype_str = 'i'
    elif dtype == int:
        dtype_str = 'i'
    return dtype_str

class FPGAManager(object):
    def __init__(self,
            pci_cl_ctrl_device='/dev/xdma0_user',
            c2h_dma_device='/dev/xdma0_c2h_0',
            h2c_dma_device='/dev/xdma0_h2c_0',
            log_level=logging.INFO):
        self.log = logging.getLogger('FPGA Manager')
        self.log.setLevel(log_level)
        self.fpga_memspace = FPGAMemSpace(
                pci_cl_ctrl_device=pci_cl_ctrl_device,
                c2h_dma_device=c2h_dma_device,
                h2c_dma_device=h2c_dma_device,
                log_level=logging.INFO)
        self.input_op = None
        self.output_t = None

    # TODO: this is not a general impl. Needs to be cleaned up after hotchips.
    def send_input_nparr(self, input_nparr):
        # data
        op = self.input_op
        op.data.data = input_nparr
        tin = op.data
        self.log.debug('Sending tensor {} to fpga'.format(op.data))
        pad = op.pad
        b, I, _, ic = tin.fpga_shape
        padded_data = _pad_tensor(tin)
        self.fpga_memspace.write('ddr', tin.fpga_addr, padded_data)
        self.log.debug('tensor data: \n{}'.format(tin.data))

    # TODO: this is not a general impl. Needs to be cleaned up after hotchips.
    def find_sink_op(self, graph):
        for tname, t in graph.tensor_registry.items():
            if len(t.output_nodes) == 0:
                self.output_t = t
                break

    def get_tout_frac_bits(self):
#        print str(self.output_t.name) + " " + str(self.output_t.dtype.frac_bits)
        return self.output_t.dtype.frac_bits

    def _unpad_tensor(self, t, data):
        return data[
                t.fpga_pad[0][0]:t.fpga_pad[0][0]+t.shape[0],
                t.fpga_pad[1][0]:t.fpga_pad[1][0]+t.shape[1],
                t.fpga_pad[2][0]:t.fpga_pad[2][0]+t.shape[2],
                t.fpga_pad[3][0]:t.fpga_pad[3][0]+t.shape[3]
                ]

    # TODO: this is not a general impl. Needs to be cleaned up after hotchips.
    def recv_output_nparr(self):
        t = self.output_t
        op = self.output_t.op
        self.log.debug('{}'.format(t))
        self.log.debug('OP name: {}'.format(op.name))
        self.log.debug('OP output address: {}'.format(t.fpga_addr))
        got_out_fpga = np.array(array.array('h', self.fpga_memspace.read('ddr', t.fpga_addr, t.fpga_size_in_bytes)), dtype=np.int16).reshape(t.fpga_shape)
        got_out_fpga = self._unpad_tensor(t, got_out_fpga)
        return got_out_fpga

    def initialize_graph_tensors(self, graph):
        self.log.debug('Initializing tensors')
        for tname, t in graph.tensor_registry.items():
            self.log.debug('Tensor {}'.format(t))
            if t.dtype.bits == 32:
                dtype = np.int32
            else:
                dtype = np.int16
            if t.op is None:
                t.data = np.random.randint(0, 16, t.size).astype(dtype).reshape(t.shape) * (1<<4)
            else:
                t.data = np.zeros(t.shape, dtype=dtype)
            self.log.debug('Tensor initialized with data: \n{}'.format(t.data))

    # TODO: this is not a general impl. Needs to be cleaned up after hotchips.
    def initialize_graph(self, graph, array_m, array_n):
        self.log.info('Systolic array: {}x{}'.format(array_n, array_m))
        self.log.info('Initializing graph: {}'.format(graph.name))
        self.find_sink_op(graph)
        self.log.info('clearing data in DDR')
        self.fpga_memspace.write('ddr', 0, np.zeros((1<<28), dtype=np.int8))
        self.log.info('clearing data in DDR - done!')
        for opname, op in graph.op_registry.items():
            if isinstance(op, Convolution):
                # data
                if op.data.op is None:
                    self.input_op = op
                    tin = op.data
                    self.log.debug('Sending tensor {} to fpga addr {}'.format(op.data, tin.fpga_addr))
                    pad = op.pad
                    b, I, _, ic = tin.fpga_shape
                    padded_data = _pad_tensor(tin)
                    self.fpga_memspace.write('ddr', tin.fpga_addr, padded_data)
                    self.log.debug('tensor data: \n{}'.format(tin.data))

                else:
                    # Need zero-padding for inputs
                    op.data.data = np.zeros(op.data.shape, dtype=np.int16)
                    self.fpga_memspace.write('ddr', op.data.fpga_addr, _pad_tensor(op.data))

                # weights
                tw = op.weights
                self.log.debug('Sending tensor {} to fpga addr {}'.format(tw, tw.fpga_addr))
                oc, kh, kw, ic = tw.fpga_shape
                assert oc % array_m == 0
                tw_data = _pad_tensor(tw).reshape(int(oc/array_m),array_m,kh,kw,ic)
                tw_ddr = np.transpose(tw_data, (0,2,3,4,1)).copy()
                self.fpga_memspace.write('ddr', tw.fpga_addr, tw_ddr)
                self.log.debug('tensor data: \n{}'.format(tw.data))

                # bias
                tbias = op.bias
                self.log.debug('Sending tensor {} to fpga addr {}'.format(tbias, tbias.fpga_addr))
                self.log.debug('tensor data: \n{}'.format(tbias.data))
                tbias_ddr = np.pad(tbias.data, tbias.fpga_pad, 'constant', constant_values=(0,0))
                self.fpga_memspace.write('ddr', tbias.fpga_addr, tbias_ddr)

                # Need negative padding for conv output
                padding = sum(x[0]+x[1] for x in op.output_tensors.fpga_pad)
                if padding > 0:
                    # raise ValueError
                    # neg = np.zeros(op.output_tensors.fpga_shape, dtype=np.int64) * -1 * (1<<28)
                    neg = np.ones(op.output_tensors.fpga_shape, dtype=np.int64) * -1 * (1<<31)
                    self.fpga_memspace.write('ddr', op.output_tensors.fpga_addr, neg)
                else:
                    self.fpga_memspace.write('ddr', op.output_tensors.fpga_addr, np.zeros(op.output_tensors.fpga_size, dtype=np.int64))

            elif isinstance(op, BatchNorm):
                mean = op.mean
                scale = op.scale
                self.log.debug('Sending tensor {} to fpga addr {}'.format(mean, mean.fpga_addr))
                mean_ddr = np_array_to_ddr(mean.data, [mean.size], [1])
                self.fpga_memspace.write('ddr', mean.fpga_addr, mean_ddr)
                self.log.debug('tensor data: \n{}'.format(mean.data))
                self.log.debug('Sending tensor {} to fpga addr {}'.format(scale, scale.fpga_addr))
                scale_ddr = np_array_to_ddr(scale.data, [scale.size], [1])
                self.fpga_memspace.write('ddr', scale.fpga_addr, scale_ddr)
                self.log.debug('tensor data: \n{}'.format(scale.data))

    def write(self, namespace, addr, data):
        self.fpga_memspace.write(namespace, addr, data)

    def read(self, namespace, addr, size=None):
        return self.fpga_memspace.read(namespace, addr, size=size)

    def get_fpga_state(self):
        return self.fpga_memspace.read('pci_cl_ctrl', 8)

    def wait_fpga_execution(self):
        state = self.get_fpga_state()
        if state != 0:
            while state != 0:
                state = self.get_fpga_state()
#                sleep(0.0001)

    def start(self):
        self.fpga_memspace.write('pci_cl_ctrl', 0, 1)
        self.fpga_memspace.write('pci_cl_ctrl', 0, 0)

    def print_fpga_registers(self):
        ibuf_rd_req = self.fpga_memspace.read('pci_cl_ctrl', 16*4)
        ibuf_rd_finished = self.fpga_memspace.read('pci_cl_ctrl', 17*4)
        obuf_wr_req = self.fpga_memspace.read('pci_cl_ctrl', 18*4)
        obuf_wr_finished = self.fpga_memspace.read('pci_cl_ctrl', 19*4)
        obuf_rd_req = self.fpga_memspace.read('pci_cl_ctrl', 20*4)
        obuf_rd_finished = self.fpga_memspace.read('pci_cl_ctrl', 21*4)

        reg22 = self.fpga_memspace.read('pci_cl_ctrl', 22*4)
        obuf_ld_stream_read_count = reg22 >> 16
        obuf_ld_stream_write_count = reg22 % (1<<16)
        reg23 = self.fpga_memspace.read('pci_cl_ctrl', 23*4)
        ddr_st_stream_read_count = reg23 >> 16
        ddr_st_stream_write_count = reg23 % (1<<16)

        reg24 = self.fpga_memspace.read('pci_cl_ctrl', 24*4)
        obuf_ld_stream_fifo_count = reg24 >> 16
        ddr_st_stream_fifo_count = reg24 % (1<<16)
        reg25 = self.fpga_memspace.read('pci_cl_ctrl', 25*4)
        ddr_ld1_stream_fifo_count = reg25 >> 16
        ddr_ld0_stream_fifo_count = reg25 % (1<<16)

        pu_wr_req = self.fpga_memspace.read('pci_cl_ctrl', 26*4)
        pu_wr_finished = self.fpga_memspace.read('pci_cl_ctrl', 27*4)
        pu_rd_req = self.fpga_memspace.read('pci_cl_ctrl', 28*4)
        pu_rd_finished = self.fpga_memspace.read('pci_cl_ctrl', 29*4)
        pu_state = self.fpga_memspace.read('pci_cl_ctrl', 30*4)
        pu_obuf_reads = self.fpga_memspace.read('pci_cl_ctrl', 31*4)
        accelerator_state = self.fpga_memspace.read('pci_cl_ctrl', 2*4)
        tag_req_count = self.fpga_memspace.read('pci_cl_ctrl', 3*4)
        compute_done_count = self.fpga_memspace.read('pci_cl_ctrl', 4*4)
        pu_compute_start_count = self.fpga_memspace.read('pci_cl_ctrl', 6*4)
        pu_compute_done_count = self.fpga_memspace.read('pci_cl_ctrl', 5*4)

        reg7 = self.fpga_memspace.read('pci_cl_ctrl', 7*4)
        stmem_state = reg7 >> 16
        stmem_tag = reg7 % 2
        stmem_ddr_pe_sw = (reg7 >> 1) % 2


        reg13 = self.fpga_memspace.read('pci_cl_ctrl', 13*4)
        reg14 = self.fpga_memspace.read('pci_cl_ctrl', 14*4)
        reg15 = self.fpga_memspace.read('pci_cl_ctrl', 15*4)
        ld0_stream_read_count = reg13 >> 16
        ld0_stream_write_count = reg13 % (1<<16)

        ld1_stream_read_count = reg14 >> 16
        ld1_stream_write_count = reg14 % (1<<16)

        pu_axi_wdata_fifo_count = reg15 >> 16
        pu_axi_awbuf_fifo_count = reg15 % (1<<16)


        self.log.info('*'*50)
        self.log.info('Printing fpga registers:')
        self.log.info('*'*50)
        self.log.info('fpga  : pu   state                  : {}'.format(pu_state))
        self.log.info('fpga  : accelerator state           : {}'.format(accelerator_state))
        self.log.info('fpga  : stmem state                 : {}'.format(stmem_state))
        self.log.info('*'*50)
        self.log.info('AXI')
        self.log.info('fpga  : ibuf axi rd requested       : {}'.format(ibuf_rd_req))
        self.log.info('fpga  : ibuf axi rd finished        : {}'.format(ibuf_rd_finished))
        self.log.info('fpga  : obuf axi wr requested       : {}'.format(obuf_wr_req))
        self.log.info('fpga  : obuf axi wr finished        : {}'.format(obuf_wr_finished))
        self.log.info('fpga  : obuf axi rd requested       : {}'.format(obuf_rd_req))
        self.log.info('fpga  : obuf axi rd finished        : {}'.format(obuf_rd_finished))
        self.log.info('fpga  : pu   axi wr requested       : {}'.format(pu_wr_req))
        self.log.info('fpga  : pu   axi wr finished        : {}'.format(pu_wr_finished))
        self.log.info('fpga  : pu   axi rd requested       : {}'.format(pu_rd_req))
        self.log.info('fpga  : pu   axi rd finished        : {}'.format(pu_rd_finished))

        self.log.info('FIFO')
        self.log.info('fpga  : obuf stream rd count        : {}'.format(obuf_ld_stream_read_count))
        self.log.info('fpga  : obuf stream wr count        : {}'.format(obuf_ld_stream_write_count))
        self.log.info('fpga  : obuf stream fifo count      : {}'.format(obuf_ld_stream_fifo_count))
        self.log.info('fpga  : ddr  stream rd count        : {}'.format(ddr_st_stream_read_count))
        self.log.info('fpga  : ddr  stream wr count        : {}'.format(ddr_st_stream_write_count))
        self.log.info('fpga  : ddr  stream fifo count      : {}'.format(ddr_st_stream_fifo_count))
        self.log.info('fpga  : ld0  stream fifo count      : {}'.format(ddr_ld0_stream_fifo_count))
        self.log.info('fpga  : ld1  stream fifo count      : {}'.format(ddr_ld1_stream_fifo_count))
        self.log.info('fpga  : pu   obuf reads             : {}'.format(pu_obuf_reads))

        self.log.info('*'*50)
        self.log.info('fpga  : axi awreq buf fifo count    : {}'.format(pu_axi_awbuf_fifo_count))
        self.log.info('fpga  : axi wdata buf fifo count    : {}'.format(pu_axi_wdata_fifo_count))
        self.log.info('fpga  : ld0 write count             : {}'.format(ld0_stream_write_count))
        self.log.info('fpga  : ld0 read count              : {}'.format(ld0_stream_read_count))
        self.log.info('fpga  : ld1 write count             : {}'.format(ld1_stream_write_count))
        self.log.info('fpga  : ld1 read count              : {}'.format(ld1_stream_read_count))
        self.log.info('*'*50)

        self.log.info('Blocks')
        self.log.info('fpga  : tag req count               : {}'.format(tag_req_count))
        self.log.info('fpga  : compute done count          : {}'.format(compute_done_count))
        self.log.info('fpga  : pu compute start count      : {}'.format(pu_compute_start_count))
        self.log.info('fpga  : pu compute done count       : {}'.format(pu_compute_done_count))
        self.log.info('fpga  : stmem tag                   : {}'.format(stmem_tag))
        self.log.info('fpga  : stmem_ddr_pe_sw             : {}'.format(stmem_ddr_pe_sw))
        self.log.info('*'*50)
