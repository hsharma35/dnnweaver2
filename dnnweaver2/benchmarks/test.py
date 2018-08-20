from dnnweaver2.graph import Graph, get_default_graph

from dnnweaver2.tensorOps.cnn import conv2D, maxPool, flatten, matmul, addBias, batch_norm, reorg, concat, leakyReLU
from dnnweaver2 import get_tensor
import logging
from dnnweaver2.scalar.dtypes import FQDtype, FixedPoint

from dnnweaver2 import get_tensor


def yolo_convolution(tensor_in, filters=32, kernel_size=3,
        batch_normalize=True, act='leakyReLU',
        c_dtype=None, w_dtype=None,
        s_dtype=None, bn_dtype=None):

    input_channels = tensor_in.shape[-1]

    weights = get_tensor(shape=(filters, kernel_size, kernel_size, input_channels),
                         name='weights',
                         dtype=w_dtype)
    biases = get_tensor(shape=(filters),
                         name='biases',
                         dtype=FixedPoint(32,w_dtype.frac_bits + tensor_in.dtype.frac_bits))
    conv = conv2D(tensor_in, weights, biases, pad='SAME', dtype=c_dtype)

    if batch_normalize:
        with get_default_graph().name_scope('batch_norm'):
            mean = get_tensor(shape=(filters), name='mean', dtype=FixedPoint(16,c_dtype.frac_bits))
            scale = get_tensor(shape=(filters), name='scale', dtype=s_dtype)
            bn = batch_norm(conv, mean=mean, scale=scale, dtype=bn_dtype)
    else:
        bn = conv

    if act == 'leakyReLU':
        with get_default_graph().name_scope(act):
            act = leakyReLU(bn, dtype=bn.dtype)
    elif act == 'linear':
        with get_default_graph().name_scope(act):
            act = bn
    else:
        raise ValueError, 'Unknown activation type {}'.format(act)

    return act


def get_graph(train=False):
    g = Graph('YOLOv2-Test: 16-bit', dataset='imagenet', log_level=logging.INFO)
    batch_size = 1

    with g.as_default():

        with g.name_scope('inputs'):
            # Input dimensions are (Batch_size, Height, Width, Channels)
            i = get_tensor(shape=(batch_size,28,28,1), name='data', dtype=FQDtype.FXP16, trainable=False)

        with g.name_scope('conv0'):
            # Weight dimensions are (Output Channels, Kernel Height, Kernel Width, Input Channels)
            weights = get_tensor(shape=(20, 5, 5, 1),
                                 name='weights',
                                 dtype=FixedPoint(16,12))
            # Bias dimensions are (Output Channels,)
            biases = get_tensor(shape=(20),
                                 name='biases',
                                 dtype=FixedPoint(32,20))
            # Intermediate data dimensions are (Batch_size, Height, Width, Channels)
            conv = conv2D(i, weights, biases, pad='VALID', dtype=FixedPoint(16,12))

    return g

