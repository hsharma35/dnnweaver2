import logging
import mmap
import os
import numpy as np
import array
import codecs

decode_hex = codecs.getdecoder("hex_codec")
def to_bytes(n, length, endianess='big'):
    h = '%x' % n
    s = decode_hex(('0'*(len(h) % 2) + h).zfill(length*2))[0]
    return s if endianess == 'big' else s[::-1]

class FPGAMemSpace(object):
    def __init__(self,
            pci_cl_ctrl_device='/dev/xdma/card0/user',
            c2h_dma_device='/dev/xdma/card0/c2h0',
            h2c_dma_device='/dev/xdma/card0/h2c0',
            log_level=logging.INFO):
        self.log = logging.getLogger('FPGA Memspace')
        self.log.setLevel(log_level)

        self.log.debug('Opening device: {}'.format(pci_cl_ctrl_device))
        self.pci_cl_ctrl_fd = open(pci_cl_ctrl_device, 'r+b', buffering=0)
        self.pci_cl_ctrl_mmap = mmap.mmap(self.pci_cl_ctrl_fd.fileno(), 32*1024, prot=mmap.PROT_READ|mmap.PROT_WRITE)

        self.log.debug('Opening device: {}'.format(h2c_dma_device))
        self.h2c_fd = os.open(h2c_dma_device, os.O_RDWR)

        self.log.debug('Opening device: {}'.format(c2h_dma_device))
        self.c2h_fd = os.open(c2h_dma_device, os.O_RDWR)

        self.inst_buffer_addr = 0x100000000

    def write(self, namespace, addr, data):
        assert namespace in ('pci_cl_data', 'pci_cl_ctrl', 'ddr')

        if namespace == 'pci_cl_ctrl':
            self.pci_cl_ctrl_mmap.seek(addr)
            self.pci_cl_ctrl_mmap.write(to_bytes(data, 4, 'little'))
        elif namespace == 'pci_cl_data':
            os.lseek(self.h2c_fd, addr+self.inst_buffer_addr, 0)
            os.write(self.h2c_fd, data)
        else:
            self.log.debug('Writing data {} with dtype {} to address {}'.format(
                data, data.dtype, addr))
            os.lseek(self.h2c_fd, addr, 0)
            os.write(self.h2c_fd, data)

    def read(self, namespace, addr, size=None):
        assert namespace in ('pci_cl_data', 'pci_cl_ctrl', 'ddr')

        if namespace == 'pci_cl_ctrl':
            self.pci_cl_ctrl_mmap.seek(addr)
            v = self.pci_cl_ctrl_mmap.read(4)
            if isinstance(v, bytes):
                v = v.decode('utf-8')
            v = '0x'+''.join([hex(ord(i))[2:].zfill(2) for i in reversed(v)])
            return int(v, 16)
        elif namespace == 'pci_cl_data':
            os.lseek(self.c2h_fd, addr+self.inst_buffer_addr, 0)
            return np.array(array.array('i', os.read(self.c2h_fd, size)), dtype=np.int32)
        else:
            self.log.debug('Reading tensor of size {} Bytes from address {}'.format(size, addr))
            os.lseek(self.c2h_fd, addr, 0)
            return os.read(self.c2h_fd, int(size))

