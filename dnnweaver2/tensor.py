from dnnweaver2.scalar.dtypes import FQDtype
import numpy as np
import math

class Tensor(object):
    """
    Tensor class for computations
        n-dimensional array
    """
    def __init__(self, shape, name, data, dtype=FQDtype.FP32, trainable=False):
        if isinstance(shape, int):
            shape = tuple([shape])
        self.shape = shape
        self.dtype = dtype
        self.name = name
        self.trainable = trainable
        self.op = None
        self.output_nodes = []
        self.data = data

        self.fpga_addr = None
        _pad = []
        for i in range(len(self.shape)):
            _pad.append((0,0))
        self.fpga_pad = tuple(_pad)

    def initialize_data(self, value):
        self.data = value

    def __str__(self):
        if isinstance(self.shape, tuple):
            shape_str = '[' + ','.join([str(x) for x in self.shape]) + ']'
        else:
            shape_str = '[' + str(self.shape) + ']'
        return '{}{} ({})'.format(self.name, shape_str, self.dtype.__str__())
        # return '{}{}'.format(self.name, shape_str)

    @property
    def size(self):
        return np.prod(self.shape)

    @property
    def fpga_shape(self):
        _padded_shape = []
        for i in range(len(self.shape)):
            _padded_shape.append(self.shape[i] + self.fpga_pad[i][0] + self.fpga_pad[i][1])
        return tuple(_padded_shape)

    @property
    def fpga_size(self):
        return np.prod(self.fpga_shape)

    @property
    def fpga_size_in_bytes(self):
        return self.fpga_size * self.dtype.bits / 8

    @property
    def size_in_bytes(self):
        return int(math.ceil(float(self.size * self.dtype.bits) / 8))

