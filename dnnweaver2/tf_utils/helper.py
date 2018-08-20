import numpy as np
import tensorflow as tf

#----- Different NN layers and functions to requied make a DNN -----#
def conv_simple(input, kernel, bias, s_h, s_w, padding='SAME', relu=True):
	x = tf.nn.conv2d(input, kernel, strides=[1, s_h, s_w, 1], padding=padding)
	x = tf.nn.bias_add(x, bias)
	if relu:
		x = tf.nn.relu(x)
	return x

def conv(input, kernel, biases, s_h, s_w, relu=True, padding='SAME', group=1):
	convolve = lambda i, k: tf.nn.conv2d(i, k, [1, s_h, s_w, 1], padding=padding)
	if group == 1:
		output = convolve(input, kernel)
	else:
		input_groups = tf.split(input, group, 3)
		kernel_groups = tf.split(kernel, group, 3)
		output_groups = [convolve(i, k) for i, k in zip(input_groups, kernel_groups)]
		output = tf.concat(output_groups, 3)
	output = tf.nn.bias_add(output, biases)
	if relu:
		output = tf.nn.relu(output)
	return output
	
def max_pool(input, k_h, k_w, s_h, s_w, padding='SAME'):
	return tf.nn.max_pool(input, ksize=[1, k_h, k_w, 1], strides=[1, s_h, s_w, 1], padding=padding)
	
def softmax(input):
	input_shape = map(lambda v: v.value, input.get_shape())
	if len(input_shape) > 2:
		if input_shape[1] == 1 and input_shape[2] == 1:
			input = tf.squeeze(input, squeeze_dims=[1, 2])
		else:
			raise ValueError('Rank 2 tensor input expected for softmax!')
	return tf.nn.softmax(input)
	
def lrn(input, radius, alpha, beta, bias=1.0):
	return tf.nn.local_response_normalization(input, depth_radius=radius, alpha=alpha, beta=beta, bias=bias)

def fc(input, weights, biases, relu=True):
	input_shape = input.get_shape()
	if input_shape.ndims == 4:
		dim = 1
		for d in input_shape[1:].as_list():
			dim *= d
		feed_in = tf.reshape(input, [-1, dim])
	else:
		feed_in, dim = (input, input_shape[-1].value)
	op = tf.nn.relu_layer if relu else tf.nn.xw_plus_b
	return op(feed_in, weights, biases)


#----- Classes and methods required to get network data specification, e.g., batch size, crop size, etc. -----#
class DataSpec(object):
	def __init__(self, batch_size, scale_size, crop_size, isotropic, channels=3, mean=None, bgr=True):
			self.batch_size = batch_size
			self.scale_size = scale_size
			self.isotropic = isotropic
			self.crop_size = crop_size
			self.channels = channels
			self.mean = mean if mean is not None else np.array([104., 117., 124.])
			self.expects_bgr = True
	
def alexnet_spec(batch_size=20):
	return DataSpec(batch_size=batch_size, scale_size=256, crop_size=227, isotropic=False)
	
def lenet_spec(batch_size=1):
	return DataSpec(batch_size=batch_size, scale_size=28, crop_size=28, isotropic=False, channels=1)
	
def std_spec(batch_size, isotropic=True):
	return DataSpec(batch_size=batch_size, scale_size=256, crop_size=224, isotropic=isotropic)

MODEL_DATA_SPECS = {
	'AlexNet': alexnet_spec(),
	'SqueezeNet': alexnet_spec(),
	'CaffeNet': alexnet_spec(),
	'GoogleNet': std_spec(batch_size=20, isotropic=False),
	'ResNet50': std_spec(batch_size=25),
	'ResNet101': std_spec(batch_size=25),
	'ResNet152': std_spec(batch_size=25),
	'NiN': std_spec(batch_size=20),
	'VGG16': std_spec(batch_size=1),
	'LeNet': lenet_spec()
}
	
def get_data_spec(model_class):
	return MODEL_DATA_SPECS[model_class]

#----- Methods required to load a trained network ckpt file and return W/B/Names -----#
#----- These already work for ckpt converted from caffe, not necessarily for tf saved ones -----#

#Retrieve W/B/Names as dictionaries of np arrays; example usecase: weights['conv1']
def load_netparams(ckpt_path):
	data_dict = np.load(ckpt_path).item()
	weights = {}
	biases = {}
	layer_names = []
	for op_name in data_dict:
		layer_names.append(op_name)
		for param_name, data in data_dict[op_name].iteritems():
			if param_name == 'weights':
				weights[op_name] = data
			elif param_name == 'biases':
				biases[op_name] = data
			assert (param_name != 'weights' or param_name != 'biases')
	return weights, biases, layer_names

#Retrieve W/B/Names as dictionaries of tensorflow variables
def load_netparams_tf(ckpt_path, trainable=False):
	data_dict = np.load(ckpt_path).item()
	weights = {}
	biases = {}
	layer_names = []
	for op_name in data_dict:
		layer_names.append(op_name)
		with tf.variable_scope(op_name):
			for param_name, data in data_dict[op_name].iteritems():
				if param_name == 'weights':
					weights[op_name] = tf.get_variable(name=param_name, initializer=tf.constant(data), trainable=trainable)
				elif param_name == 'biases':
					biases[op_name] = tf.get_variable(name=param_name, initializer=tf.constant(data), trainable=trainable)
				assert (param_name != 'weights' or param_name != 'biases')
	return weights, biases, layer_names

#Simple example of quantizing the network parameters
def load_netparams_tf_quantize(ckpt_path, trainable=False):
	data_dict = np.load(ckpt_path).item()
	weights = {}
	biases = {}
	layer_names = []
	for op_name in data_dict:
		layer_names.append(op_name)
		with tf.variable_scope(op_name):
			for param_name, data_temp in data_dict[op_name].iteritems():
				#data = data_temp if op_name == 'conv1' else ((np.array(data_temp * 126, int)).astype(np.float32)) / 126
				data = ((np.array(data_temp * 256, int)).astype(np.float32)) / 256
				if param_name == 'weights':
					weights[op_name] = tf.get_variable(name=param_name, initializer=tf.constant(data), trainable=trainable)
				elif param_name == 'biases':
					biases[op_name] = tf.get_variable(name=param_name, initializer=tf.constant(data), trainable=trainable)
				assert (param_name != 'weights' or param_name != 'biases')
	return weights, biases, layer_names

