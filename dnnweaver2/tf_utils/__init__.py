import tensorflow as tf
import time
from datetime import datetime
import math
from pynvml import *
import tensorpack
import os
from tqdm import tqdm, trange

import numpy as np

from dnnweaver2.tf_utils.dataset import ImageNetProducer
from dnnweaver2.tf_utils.helper import DataSpec

def time_tensorflow_run(session, target, info_string, input_shape, labels_shape, images, labels):
    num_batches = 100
    num_steps_burn_in = 10
    b, c, h, w = input_shape
    # np_images_shape = tuple(np_images_shape)
    np_images = np.random.rand(b,h,w,c)
    np_labels = np.random.randint(0,10,size=(b,))
    total_duration = 0.0
    total_duration_squared = 0.0
    if not isinstance(target, list):
        target = [target]
    target_op = tf.group(*target)
    for i in range(num_batches + num_steps_burn_in):
        start_time = time.time()
        _ = session.run(target_op, feed_dict={images:np_images, labels:np_labels})
        duration = time.time() - start_time
        if i > num_steps_burn_in:
            if not i % 10:
                print ('%s: step %d, duration = %.3f' %
                       (datetime.now(), i - num_steps_burn_in, duration))
            total_duration += duration
            total_duration_squared += duration * duration

    mn = total_duration / num_batches
    vr = total_duration_squared / num_batches - mn * mn
    sd = math.sqrt(vr)
    print ('%s: %s across %d steps, %.3f +/- %.3f sec / batch' %
           (datetime.now(), info_string, num_batches, mn, sd))
    return mn, sd

def create_tf_graph(dataset, fq_graph, train):

    graph_inputs = {}

    g = tf.Graph()
    print('Creating Tensorflow graph for {}'.format(fq_graph.name))

    if 'qnn' in fq_graph.name.lower():
        quantization_type = 'qnn'
    elif 'dorefa' in fq_graph.name.lower():
        quantization_type = 'dorefa'
    elif 'wrpn' in fq_graph.name.lower():
        quantization_type = 'wrpn'
    else:
        raise ValueError, 'Unknown quantization type for network: {}'.format(fq_graph.name)

    print('Gradient dtype: {}'.format(fq_graph.grad_dtype))
    grad_dtype = fq_graph.grad_dtype
    grad_bits = grad_dtype.bits
    print('Gradient dtype bits: {}'.format(grad_bits))

    nvmlInit()
    gpu_handle = nvmlDeviceGetHandleByIndex(0)
    gpu_name = nvmlDeviceGetName(gpu_handle)

    def get_sparsity(x):
        with g.name_scope('sparsity_op'):
            with tf.device("/cpu:0"):
                x_size = tf.cast(tf.size(x), tf.float32)
                non_zero = tf.count_nonzero(x, dtype=tf.float32)
                sparsity = 1. - (non_zero / x_size)
                return sparsity

    def quantize(x, k):
        with tf.device("/gpu:0"):
            n = float(2**k - 1)
            with g.gradient_override_map({"Round": "Identity"}):
                return tf.round(x * n) / n

    try:
        @tf.RegisterGradient("FGGrad_1bit")
        def grad_fg_1(op, x):
            with tf.device("/cpu:0"):
                tf.summary.scalar('backprop-sparsity', get_sparsity(x))
            with tf.device("/gpu:0"):
                bitG = 1
                rank = x.get_shape().ndims
                assert rank is not None
                maxx = tf.reduce_max(tf.abs(x), list(range(1, rank)), keep_dims=True)
                x = x / maxx
                n = float(2**bitG - 1)
                x = x * 0.5 + 0.5 + tf.random_uniform(
                    tf.shape(x), minval=-0.5 / n, maxval=0.5 / n)
                x = tf.clip_by_value(x, 0.0, 1.0)
                x = quantize(x, bitG) - 0.5
                return x * maxx * 2

        @tf.RegisterGradient("FGGrad_2bit")
        def grad_fg_2(op, x):
            with tf.device("/cpu:0"):
                tf.summary.scalar('backprop-sparsity', get_sparsity(x))
            with tf.device("/gpu:0"):
                bitG = 2
                rank = x.get_shape().ndims
                assert rank is not None
                maxx = tf.reduce_max(tf.abs(x), list(range(1, rank)), keep_dims=True)
                x = x / maxx
                n = float(2**bitG - 1)
                x = x * 0.5 + 0.5 + tf.random_uniform(
                    tf.shape(x), minval=-0.5 / n, maxval=0.5 / n)
                x = tf.clip_by_value(x, 0.0, 1.0)
                x = quantize(x, bitG) - 0.5
                return x * maxx * 2

        @tf.RegisterGradient("FGGrad_4bit")
        def grad_fg_4(op, x):
            with tf.device("/cpu:0"):
                tf.summary.scalar('backprop-sparsity', get_sparsity(x))
            bitG = 4
            with tf.device("/gpu:0"):
                rank = x.get_shape().ndims
                assert rank is not None
                maxx = tf.reduce_max(tf.abs(x), list(range(1, rank)), keep_dims=True)
                x = x / maxx
                n = float(2**bitG - 1)
                x = x * 0.5 + 0.5 + tf.random_uniform(
                    tf.shape(x), minval=-0.5 / n, maxval=0.5 / n)
                x = tf.clip_by_value(x, 0.0, 1.0)
                x = quantize(x, bitG) - 0.5
                return x * maxx * 2

        @tf.RegisterGradient("FGGrad_8bit")
        def grad_fg_8(op, x):
            with tf.device("/cpu:0"):
                tf.summary.scalar('backprop-sparsity', get_sparsity(x))
            with tf.device("/gpu:0"):
                bitG = 8
                rank = x.get_shape().ndims
                assert rank is not None
                maxx = tf.reduce_max(tf.abs(x), list(range(1, rank)), keepdims=True)
                x = x / maxx
                n = float(2**bitG - 1)
                x = x * 0.5 + 0.5 + tf.random_uniform(
                    tf.shape(x), minval=-0.5 / n, maxval=0.5 / n)
                x = tf.clip_by_value(x, 0.0, 1.0)
                x = quantize(x, bitG) - 0.5
                return x * maxx * 2

        @tf.RegisterGradient("FGGrad_16bit")
        def grad_fg_16(op, x):
            with tf.device("/cpu:0"):
                tf.summary.scalar('backprop-sparsity', get_sparsity(x))
            with tf.device("/gpu:0"):
                bitG = 16
                rank = x.get_shape().ndims
                assert rank is not None
                maxx = tf.reduce_max(tf.abs(x), list(range(1, rank)), keep_dims=True)
                x = x / maxx
                n = float(2**bitG - 1)
                x = x * 0.5 + 0.5 + tf.random_uniform(
                    tf.shape(x), minval=-0.5 / n, maxval=0.5 / n)
                x = tf.clip_by_value(x, 0.0, 1.0)
                x = quantize(x, bitG) - 0.5
                return x * maxx * 2

        @tf.RegisterGradient("FGGrad_32bit")
        def grad_fg_32(op, x):
            with tf.device("/cpu:0"):
                tf.summary.scalar('backprop-sparsity', get_sparsity(x))
            return x
    except:
        pass

    def dorefa_quantize_gradient(x, bitG):
        with tf.device("/gpu:0"):
            grad_name = 'FGGrad_{}bit'.format(bitG)
            with g.gradient_override_map({"Identity": grad_name}):
                return tf.identity(x)

    def dorefa_quantize_weights(x, bitW):
        with tf.device("/gpu:0"):
            if bitW == 32:
                return x
            if bitW == 1:   # BWN
                with g.gradient_override_map({"Sign": "Identity"}):
                    E = tf.stop_gradient(tf.reduce_mean(tf.abs(x)))
                    return tf.sign(x / E) * E
            x = tf.tanh(x)
            x = x / tf.reduce_max(tf.abs(x)) * 0.5 + 0.5
            return 2 * quantize(x, bitW) - 1

    def wrpn_quantize_weights(x, bitW):
        with tf.device("/gpu:0"):
            cx = tf.clip_by_value(x, -1, 1)
            return quantize(cx, bitW-1)

    def dorefa_quantize_activations(x, bitA):
        with tf.device("/gpu:0"):
            if bitA == 32:
                return x
            return quantize(x, bitA)

    def wrpn_quantize_activations(x, bitA):
        with tf.device("/gpu:0"):
            if bitA == 32:
                return x
            cx = tf.clip_by_value(x, 0, 1)
            return quantize(cx, bitA)

    def _get_weights(shape, name, bits):
        w = tf.Variable(tf.random_normal(shape,
                                         dtype=tf.float32,
                                         stddev=1e-1
                                        ),
                        trainable=True,
                        name=name)
        if quantization_type == 'qnn':
            return dorefa_quantize_weights(w, bits)
        elif quantization_type == 'dorefa':
            return dorefa_quantize_weights(w, bits)
        else:
            return wrpn_quantize_weights(w, bits)

    def _get_inputs(shape, name):
            if 'data' in name:
                print(name, shape)
                n, c, h, w = shape
                graph_inputs['inputs/data'] = tf.placeholder(tf.float32, shape=[n,h,w,c], name=name)
                return tf.transpose(graph_inputs['inputs/data'], [0,3,1,2])
            else:
                print(name, shape)
                batch, num_classes = shape[0], shape[1]
                graph_inputs['inputs/labels'] = tf.placeholder(tf.int32, shape=[batch], name=name)
                return tf.one_hot(graph_inputs['inputs/labels'], num_classes)

    def _nonlin(x, bits):
        if bits == 32:
            return tf.nn.relu(x)
        return tf.clip_by_value(x, 0., 1.)

    def _activation(x, bits):
        with tf.device("/gpu:0"):
            with tf.name_scope('activation'):
                if quantization_type == 'dorefa':
                    qa = dorefa_quantize_activations(_nonlin(x, bits), bits)
                    ret = dorefa_quantize_gradient(qa, grad_bits)
                elif quantization_type == 'qnn':
                    qa = dorefa_quantize_activations(_nonlin(x, bits), bits)
                    ret = dorefa_quantize_gradient(qa, grad_bits)
                else:
                    # act = tf.nn.relu(x)
                    qa = wrpn_quantize_activations(act, bits)
                    ret = dorefa_quantize_gradient(qa, 32)
                return ret

    def _conv(op):

        with tf.name_scope(op.name):
            strides = [1, 1, op.stride[-2], op.stride[-1]]
            i = tf_tensor_registry[op.data.name]

            with tf.device("/cpu:0"):
                tf.summary.scalar('fwdprop-sparsity', get_sparsity(i))

            with tf.device("/gpu:0"):
                cout = op.weights.shape[-4]
                cin = op.weights.shape[-3]
                kh = op.weights.shape[-2]
                kw = op.weights.shape[-1]
                w = _get_weights([kh, kw, cin, cout],
                                 name=op.weights.name,
                                 bits=op.weights.dtype.bits
                                )
                b = _get_weights([cout],
                                 name=op.name + 'bias',
                                 bits=op.weights.dtype.bits
                                )
                pad = 'SAME' if op.pad[0] > 0 else 'VALID'
                if i.shape[1] != cin:
                    i = tf.transpose(i, [0,3,1,2])
                conv_out = tf.nn.conv2d(i, w, strides, pad, name=op.name, data_format='NCHW')
                o = _activation(
                    tf.nn.bias_add(conv_out, b, data_format='NCHW'),
                    op.output_tensors.dtype.bits
                )
                tf_tensor_registry[op.output_tensors.name] = o
                # print(op.output_tensors.name)

    def _maxpool(op):
        with tf.device("/gpu:0"):
            with tf.name_scope(op.name):
                strides = [1, 1, op.stride[-2], op.stride[-1]]
                i = tf_tensor_registry[op.data.name]
                pad = 'SAME' if op.pad[0] > 0 else 'VALID'
                kernel = [1, 1, op.pooling_kernel[-2], op.pooling_kernel[-1]]
                o = tf.nn.max_pool(i, kernel, strides, pad, data_format='NCHW')
                tf_tensor_registry[op.output_tensors.name] = o

    def _flatten(op):
        with tf.device("/gpu:0"):
            with tf.name_scope(op.name):
                i = tf_tensor_registry[op.data.name]
                o = tf.reshape(i, op.output_tensors.shape)
                tf_tensor_registry[op.output_tensors.name] = o

    def _matmul(op):
            with tf.name_scope(op.name):
                with tf.device("/cpu:0"):
                    w = _get_weights(op.weights.shape,
                                     name=op.weights.name,
                                     bits=op.weights.dtype.bits
                                    )
                    b = tf.Variable(tf.constant(0.0, shape=[op.output_tensors.shape[-1]], dtype=tf.float32),
                                    trainable=True, name='biases')
                    i = tf_tensor_registry[op.data.name]
                    tf.summary.scalar('fwdprop-sparsity', get_sparsity(i))
                with tf.device("/gpu:0"):
                    o = _activation(
                        tf.matmul(i, w) + b,
                        op.output_tensors.dtype.bits
                    )
                    tf_tensor_registry[op.output_tensors.name] = o

    def _xentropy(op):
        with tf.device("/gpu:0"):
            with tf.name_scope('X-entropy'):
                logits = tf_tensor_registry[op.logits.name]
                tf_tensor_registry['logits'] = logits
                labels = tf_tensor_registry[op.labels.name]
                cross_entropy = tf.nn.softmax_cross_entropy_with_logits_v2(
                    logits=logits, labels=labels, name=op.output_tensors.name)
                tf_tensor_registry['loss'] = cross_entropy

    def _concat(op):
        with tf.device("/gpu:0"):
            with tf.name_scope(op.name):
                assert len(op.data) > 1, op.data
                input_tensors = [tf_tensor_registry[x.name] for x in op.data]
                o = tf.concat(input_tensors, op.concat_dim, name=op.name)
                tf_tensor_registry[op.output_tensors.name] = o

    def _add(op):
        with tf.device("/gpu:0"):
            with tf.name_scope(op.name):
                assert len(op.data) == 2, op.data
                a, b = [tf_tensor_registry[x.name] for x in op.data]
                o = a + b
                tf_tensor_registry[op.output_tensors.name] = o

    def _globalAvgPool(op):
        with tf.device("/gpu:0"):
            with tf.name_scope(op.name):
                i = tf_tensor_registry[op.data.name]
                n,c,h,w = op.data.shape
                o = tf.reduce_mean(i, [2,3])
                tf_tensor_registry[op.output_tensors.name] = o

    with g.as_default():
        tf_tensor_registry = {}
        for tname, t in fq_graph.tensor_registry.iteritems():
            if t.name.startswith('input'):
                i = _get_inputs(t.shape, t.name)
                tf_tensor_registry[tname] = i

        for opname, op in fq_graph.op_registry.iteritems():
            if op.__class__.__name__ == 'Convolution':
                _conv(op)
            elif op.__class__.__name__ == 'MaxPooling':
                _maxpool(op)
            elif op.__class__.__name__ == 'Flatten':
                _flatten(op)
            elif op.__class__.__name__ == 'MatMul':
                _matmul(op)
            elif op.__class__.__name__ == 'CrossEntropyLoss':
                _xentropy(op)
            elif op.__class__.__name__ == 'Concat':
                _concat(op)
            elif op.__class__.__name__ == 'Add':
                _add(op)
            elif op.__class__.__name__ == 'GlobalAvgPooling':
                _globalAvgPool(op)
            else:
                name = op.__class__.__name__
                assert 'Backprop' in name or 'Grad' in name, name
        loss = tf_tensor_registry['loss']

        if train:
            with tf.device("/gpu:0"):
                lr = tf.get_variable('learning_rate', initializer=1e-4, trainable=False)
                global_step = tf.train.get_or_create_global_step(graph=tf.get_default_graph())

                opt = tf.train.AdamOptimizer(lr, epsilon=1e-5)
                train_op = opt.minimize(loss, global_step=global_step)

            with tf.device("/cpu:0"):
                tf.summary.scalar('learning_rate', lr)
        else:
            train_op = loss

        graph_data = graph_inputs['inputs/data']
        graph_labels = graph_inputs['inputs/labels']
        graph_logits = tf_tensor_registry['logits']
        print(graph_data, graph_labels, graph_logits)

        return g, train_op, tf.summary.merge_all(), graph_data, graph_labels, graph_logits

class GPUPowerMonitor(object):
    def __init__(self, id):
        self.handle = nvmlDeviceGetHandleByIndex(id)
        self.measure = False
        self.measure_thread = None
        self.mean_power = 0
        self.variance_power = 0

    def measure_power(self):
        iter = 0
        mn = 0
        sd = 0
        while self.measure:
            p = nvmlDeviceGetPowerUsage(self.handle)
            mn += p
            sd += p * p
            iter += 1
            time.sleep(0.05)
        mn /= iter
        sd = sd/iter - mn * mn
        sd = math.sqrt(sd)
        self.mean_power = mn
        self.variance_power = sd

    def start(self):
        self.measure = True
        self.measure_thread = threading.Thread(target=self.measure_power, args=())
        self.measure_thread.daemon = True
        self.measure_thread.start()

    def stop(self):
        assert self.measure_thread is not None
        self.measure = False
        self.measure_thread.join()
        return self.mean_power, self.variance_power


def get_tf_performance(dnnweaver2_graph, phase):
    train = phase == 'forward+backward'
    print(train, phase)
    g, train_op, sparsity_op, data, labels, logits = create_tf_graph('random', dnnweaver2_graph, train)
    pmon = GPUPowerMonitor(0)

    input_shape = dnnweaver2_graph.tensor_registry['inputs/data'].shape
    label_shape = dnnweaver2_graph.tensor_registry['inputs/labels'].shape

    with g.as_default():
        init = tf.global_variables_initializer()
        sess = tf.Session('')
        sess.run(init)
        pmon.start()
        time_mn, time_sd = time_tensorflow_run(sess, train_op, phase, input_shape, label_shape, data, labels)

    switch = False
    p = pmon.stop()
    power_mn, power_sd = p
    power_mn /= 1000.
    power_sd /= 1000.
    return time_mn, time_sd, power_mn, power_sd

def time_tensorflow_run_breakdown(session, target, info_string, input_shape, labels_shape, images, labels, writer):
    num_batches = 10
    num_steps_burn_in = 10
    b, c, h, w = input_shape
    np_images = np.random.rand(b,h,w,c)
    np_labels = np.random.randint(0,10,size=(b,))
    total_duration = 0.0
    total_duration_squared = 0.0
    if not isinstance(target, list):
        target = [target]
    target_op = tf.group(*target)


    run_options = tf.RunOptions(trace_level=tf.RunOptions.FULL_TRACE)
    run_metadata = tf.RunMetadata()

    print('Getting breakdown')

    for i in range(num_batches + num_steps_burn_in):
        print('iteration {}'.format(i))
        if i > num_steps_burn_in:
            start_time = time.time()
            _ = session.run(target_op, options=run_options, run_metadata=run_metadata, feed_dict={images:np_images, labels:np_labels})
            duration = time.time() - start_time
            if not i % 10:
                print ('%s: step %d, duration = %.3f' %
                       (datetime.now(), i - num_steps_burn_in, duration))
                writer.add_run_metadata(run_metadata, 'step%d' % i)
            total_duration += duration
            total_duration_squared += duration * duration
        else:
            _ = session.run(target_op, feed_dict={images:np_images, labels:np_labels})

    mn = total_duration / num_batches
    vr = total_duration_squared / num_batches - mn * mn
    sd = math.sqrt(vr)
    print ('%s: %s across %d steps, %.3f +/- %.3f sec / batch' %
           (datetime.now(), info_string, num_batches, mn, sd))
    return mn, sd

def get_tf_breakdown(dnnweaver2_graph):
    g, train_op, sparsity_op, data, labels, logits = create_tf_graph('random', dnnweaver2_graph, train=True)

    input_shape = dnnweaver2_graph.tensor_registry['inputs/data'].shape
    label_shape = dnnweaver2_graph.tensor_registry['inputs/labels'].shape

    log_path = '/home/hardik/workspace/tf-logs/breakdown/{}/summary'.format(dnnweaver2_graph.name)
    save_path = '/home/hardik/workspace/tf-logs/breakdown/{}/ckpt'.format(dnnweaver2_graph.name)
    save_file = os.path.join(save_path, 'model.ckpt')

    with g.as_default():
        init = tf.global_variables_initializer()
        sess = tf.Session('')
        writer = tf.summary.FileWriter(log_path, sess.graph)
        sess.run(init)
        time_mn, time_sd = time_tensorflow_run_breakdown(sess, train_op, 'forward+backward', input_shape, label_shape, data, labels, writer)

    switch = False
    return time_mn, time_sd, power_mn, power_sd

def print_sparsity(sess, train_op, sparsity_op):
    for i in range(100):
        sess.run(train_op)
        sess.run(sparsity_op)

def get_tf_sparsity(dnnweaver2_graph, num_epochs=10):
    print(dnnweaver2_graph.name)
    g, train_op, sparsity_ops, data, labels, logits = create_tf_graph('alexnet', dnnweaver2_graph, train=True)

    data_shape = dnnweaver2_graph.tensor_registry['inputs/data'].shape
    batch_size = data_shape[0]

    print(data, labels)
    assert data is not None
    assert labels is not None
    with g.as_default():

        log_path = '/home/hardik/workspace/tf-logs/train/{}/summary'.format(dnnweaver2_graph.name)
        save_path = '/home/hardik/workspace/tf-logs/train/{}/ckpt'.format(dnnweaver2_graph.name)
        save_file = os.path.join(save_path, 'model.ckpt')

        saver = tf.train.Saver()

        if os.path.isfile(os.path.join(save_path, 'checkpoint')):
            print('Restoring model from path: {}'.format(save_path))
            # tf.reset_default_graph()
            sess = tf.Session('')
            saver.restore(sess, save_file)
        else:
            print('No checkpoint found at path: {}'.format(save_path))
            print('Initializing with random data')
            init = tf.global_variables_initializer()
            sess = tf.Session('')
            sess.run(init)
        train_writer = tf.summary.FileWriter(log_path, sess.graph)

        data_spec = DataSpec(batch_size=batch_size, scale_size=256, crop_size=data_shape[-1], isotropic=False)
        image_producer = ImageNetProducer(val_path='/imagenet-data/train/train-clean.txt', data_path='/imagenet-data/train/', data_spec=data_spec)

        predictions = tf.cast(tf.argmax(tf.nn.softmax(logits),1), tf.int32)
        correct_prediction = tf.equal(predictions, labels)
        accuracy = tf.reduce_mean(tf.cast(correct_prediction, tf.float32))
        tf.summary.scalar('train_accuracy', accuracy)

        global_step = tf.train.get_or_create_global_step(graph=g)

        merged = tf.summary.merge_all()

        i=sess.run(global_step)
        for e in range(num_epochs):
            coordinator = tf.train.Coordinator()
            threads = image_producer.start(session=sess, coordinator=coordinator)
            print('Epoch: {}'.format(e))
            for _labels, _images in tqdm(image_producer.batches(sess), total=image_producer.num_batches):
                if i%100 == 0:
                    summary, _ = sess.run([merged, train_op], feed_dict={data: _images, labels: _labels})
                    train_writer.add_summary(summary, i)
                    save_path = saver.save(sess, save_file)
                else:
                    _ = sess.run([train_op], feed_dict={data: _images, labels: _labels})
                i += 1

                if i > 1000:
                    break

            coordinator.request_stop()
            coordinator.join(threads, stop_grace_period_secs=2)
