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
        raise ValueError('Unknown activation type {}'.format(act))

    return act


def get_graph(train=False):
    g = Graph('YOLOv2-Test: 16-bit', dataset='imagenet', log_level=logging.INFO)
    batch_size = 1

    with g.as_default():

        with g.name_scope('inputs'):
            i = get_tensor(shape=(batch_size,416,416,3), name='data', dtype=FQDtype.FXP16, trainable=False)

        with g.name_scope('conv0'):
            conv0 = yolo_convolution(i, filters=16, kernel_size=3,
                    batch_normalize=True, act='leakyReLU',
                    w_dtype=FixedPoint(16,14), c_dtype=FixedPoint(16,12),
                    s_dtype=FixedPoint(16,9), bn_dtype=FixedPoint(16,8))
        with g.name_scope('pool0'):
            pool0 = maxPool(conv0, pooling_kernel=(1,2,2,1), stride=(1,2,2,1), pad='VALID')

        with g.name_scope('conv1'):
            conv1 = yolo_convolution(pool0, filters=32, kernel_size=3,
                    batch_normalize=True, act='leakyReLU',
                    w_dtype=FixedPoint(16,14), c_dtype=FixedPoint(16,8),
                    s_dtype=FixedPoint(16,14), bn_dtype=FixedPoint(16,8))
        with g.name_scope('pool1'):
            pool1 = maxPool(conv1, pooling_kernel=(1,2,2,1), stride=(1,2,2,1), pad='VALID')

        with g.name_scope('conv2'):
            conv2 = yolo_convolution(pool1, filters=64, kernel_size=3,
                    batch_normalize=True, act='leakyReLU',
                    # batch_normalize=False, act='linear',
                    w_dtype=FixedPoint(16,14), c_dtype=FixedPoint(16,10),
                    s_dtype=FixedPoint(16,13), bn_dtype=FixedPoint(16,9))
        with g.name_scope('pool2'):
            pool2 = maxPool(conv2, pooling_kernel=(1,2,2,1), stride=(1,2,2,1), pad='VALID')

        with g.name_scope('conv3'):
            conv3 = yolo_convolution(pool2, filters=128, kernel_size=3,
                    batch_normalize=True, act='leakyReLU',
                    w_dtype=FixedPoint(16,14), c_dtype=FixedPoint(16,10),
                    s_dtype=FixedPoint(16,13), bn_dtype=FixedPoint(16,10))
        with g.name_scope('pool3'):
            pool3 = maxPool(conv3, pooling_kernel=(1,2,2,1), stride=(1,2,2,1), pad='VALID')

        with g.name_scope('conv4'):
            conv4 = yolo_convolution(pool3, filters=256, kernel_size=3,
                    batch_normalize=True, act='leakyReLU',
                    w_dtype=FixedPoint(16,14), c_dtype=FixedPoint(16,11),
                    s_dtype=FixedPoint(16,13), bn_dtype=FixedPoint(16,10))
        with g.name_scope('pool4'):
            pool4 = maxPool(conv4, pooling_kernel=(1,2,2,1), stride=(1,2,2,1), pad='VALID')

        with g.name_scope('conv5'):
            conv5 = yolo_convolution(pool4, filters=512, kernel_size=3,
                    batch_normalize=True, act='leakyReLU',
                    w_dtype=FixedPoint(16,14), c_dtype=FixedPoint(16,12),
                    s_dtype=FixedPoint(16,13), bn_dtype=FixedPoint(16,11))
        with g.name_scope('pool5'):
            pool5 = maxPool(conv5, pooling_kernel=(1,2,2,1), stride=(1,1,1,1), pad=((0,0),(0,1),(0,1),(0,0)))

        with g.name_scope('conv6'):
            conv6 = yolo_convolution(pool5, filters=1024, kernel_size=3,
                    batch_normalize=True, act='leakyReLU',
                    w_dtype=FixedPoint(16,14), c_dtype=FixedPoint(16,12),
                    s_dtype=FixedPoint(16,11), bn_dtype=FixedPoint(16,9))

        with g.name_scope('conv7'):
            conv7 = yolo_convolution(conv6, filters=1024, kernel_size=3,
                    batch_normalize=True, act='leakyReLU',
                    w_dtype=FixedPoint(16,14), c_dtype=FixedPoint(16,11),
                    s_dtype=FixedPoint(16,14), bn_dtype=FixedPoint(16,12))

        with g.name_scope('conv8'):
            conv8 = yolo_convolution(conv7, filters=125, kernel_size=1,
                    batch_normalize=False, act='linear',
                    w_dtype=FixedPoint(16,14), c_dtype=FixedPoint(16,11))

    return g

