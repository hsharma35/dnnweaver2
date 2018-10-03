from dnnweaver2.tensorOps.NodeOp import NodeOp, GradOp
from dnnweaver2.graph import get_default_graph
from dnnweaver2.scalar.ops import Ops
from dnnweaver2.scalar.dtypes import FQDtype, FixedPoint
from dnnweaver2 import get_tensor
from dnnweaver2.tensor import Tensor

class TypeCastOp(NodeOp):
    def __init__(self, data, output_dtype, node_name=None):
        self.data = data
        input_tensors = data
        self.output_dtype = output_dtype
        super(TypeCastOp, self).__init__(node_name=node_name, input_tensors=input_tensors)

    def _get_output_shape(self):
        return self.data.shape

    def _get_output_dtype(self):
        return self.output_dtype

    def get_ops(self):
        return {}

class Convolution(NodeOp):
    def __init__(self, data, weights, bias, node_name, pad='SAME', stride=None, group=1, dtype=FQDtype.FP32):

        # Input data >3D
        self.data = data

        # Weights data 4D
        self.weights = weights
        assert len(self.weights.shape) == 4
        if len(self.data.shape) < 3:
            input_channels = 1
        else:
            input_channels = self.data.shape[-1]
        assert self.weights.shape[-1] == input_channels, 'Expected {} input channels in weights, got {}'.format(input_channels, self.weights.shape[-1])

        # Bias data 1D
        # if bias.dtype != self._get_output_dtype():
            # # bias = TypeCastOp(bias, self._get_output_dtype(), node_name='bias-typecast').output_tensors
        # assert bias.dtype == self._get_output_dtype()

        self.bias = bias
        assert len(bias.shape) == 1
        assert bias.shape[0] == weights.shape[-4], 'Bias shape {} does not match weights shape {}'.format(bias.shape, weights.shape)

        # Stride
        if stride is None:
            stride = (1,1,1,1)
        assert len(stride) == len(self.data.shape)
        self.stride = stride

        # Padding
        if pad == 'SAME':
            self.pad = (
                    (0,0),
                    (self.weights.shape[-3]//2, self.weights.shape[-3]//2),
                    (self.weights.shape[-2]//2, self.weights.shape[-2]//2),
                    (0,0)
                    )
        elif pad == 'VALID':
            self.pad = ((0,0), (0,0), (0,0), (0,0))
        else:
            assert len(pad) == 2
            self.pad = pad

        # Group
        self.group = group

        input_tensors = (data, weights, bias)
        self.dtype=dtype
        super(Convolution, self).__init__(node_name=node_name, input_tensors=input_tensors)

    def _get_output_shape(self):
        cout = self.weights.shape[-4]
        hout = (self.data.shape[-3] - self.weights.shape[-3] + self.pad[-3][0] + self.pad[-3][1]) // self.stride[-3] + 1
        wout = (self.data.shape[-2] - self.weights.shape[-2] + self.pad[-2][0] + self.pad[-2][1]) // self.stride[-2] + 1
        out_shape = []
        for i in range(len(self.data.shape)-3):
            out_shape.append(self.data.shape[i])
        out_shape.append(hout)
        out_shape.append(wout)
        out_shape.append(cout)
        return tuple(out_shape)

    def _get_output_dtype(self):
        total_bits = 64
        total_frac_bits = self.data.dtype.frac_bits + self.weights.dtype.frac_bits
        return FixedPoint(total_bits, total_frac_bits)

    def _autograd(self, x, y, grad_dtype=FQDtype.FP32):
        self.output_loss = self._get_incoming_gradients(y, grad_dtype)

        assert x in self.input_tensors, 'Op: {}, x: {}'.format(self.name, x.name)
        if x == self.data:
            if self.input_loss[0] is None:
                op = ConvolutionBackprop(data=self.data, weights=self.weights, output_loss=self.output_loss, pad=self.pad, stride=self.stride, group=self.group, node_name=self.name, dtype=grad_dtype)
                self.input_loss[0] = op.output_tensors
            return self.input_loss[0]
        else:
            if self.input_loss[1] is None:
                op = ConvolutionGradient(data=self.data, weights=self.weights, output_loss=self.output_loss, pad=self.pad, stride=self.stride, group=self.group, node_name=self.name, dtype=grad_dtype)
                self.input_loss[1] = op.output_tensors

            return self.input_loss[1]

    def get_ops(self):
        num = 1
        for i in range(len(self.data.shape)-3):
            num *= self.data.shape[i]

        cout = self.output_tensors.shape[-1]
        cin = self.data.shape[-1]
        hout = self.output_tensors.shape[-3]
        wout = self.output_tensors.shape[-2]

        hfil = self.weights.shape[-3]
        wfil = self.weights.shape[-2]

        mac = (wfil * hfil * cin * \
                cout * hout * wout * \
                num) // self.group

        dtypes = (self.data.dtype, self.weights.dtype, self.output_tensors.dtype)

        return {Ops.MAC(dtypes): mac}

    def load_params(self, params):
        self.weights.data = params["weights"]
        self.bias.data = params["bias"]

class ConvolutionBackprop(GradOp):
    def __init__(self, data, weights, output_loss, node_name, pad='SAME', stride=None, group=1, dtype=None):
        self.data = data
        self.weights = weights
        self.output_loss = output_loss
        input_tensors = (self.output_loss, self.weights)
        node_name = node_name + '-input-backprop'
        self.dtype=dtype

        # Stride
        if stride is None:
            stride = (1,1)
        assert len(stride) == 2
        self.stride = stride

        # Padding
        if pad == 'SAME':
            self.pad = (self.weights.shape[-2]//2,self.weights.shape[-1]//2)
        elif pad == 'VALID':
            self.pad = (0,0)
        else:
            assert len(pad) == 2
            self.pad = pad

        # Group
        self.group = group


        super(ConvolutionBackprop, self).__init__(node_name=node_name, input_tensors=input_tensors)

    def _get_output_shape(self):
        return self.data.shape

    def get_ops(self):
        num = 1
        for i in range(len(self.data.shape)-3):
            num *= self.data.shape[i]

        cout = self.output_loss[0].shape[-3]
        cin = self.data.shape[-3]
        hin = self.data.shape[-2]
        win = self.data.shape[-1]

        hfil = self.weights.shape[-2]
        wfil = self.weights.shape[-1]

        mac = (wfil * hfil * cout * \
                cin * hin * win * \
                num)/self.group

        dtypes = (self.output_loss[0].dtype, self.weights.dtype, self.output_tensors.dtype)
        return {Ops.MAC(dtypes): mac}

class ConvolutionGradient(GradOp):
    def __init__(self, data, weights, output_loss, node_name, pad='SAME', stride=None, group=1, dtype=None):
        self.data = data
        self.weights = weights
        self.output_loss = output_loss
        input_tensors = (self.output_loss, self.data)
        node_name = self.weights.name + '-grad'
        self.dtype=dtype
        # Stride
        if stride is None:
            stride = (1,1)
        assert len(stride) == 2
        self.stride = stride

        # Padding
        if pad == 'SAME':
            self.pad = (self.weights.shape[-2]//2,self.weights.shape[-1]//2)
        elif pad == 'VALID':
            self.pad = (0,0)
        else:
            assert len(pad) == 2
            self.pad = pad

        # Group
        self.group = group

        if dtype is None:
            dtype = self.graph.grad_dtype

        super(ConvolutionGradient, self).__init__(node_name=node_name, input_tensors=input_tensors)

    def _get_output_shape(self):
        return self.weights.shape

    def get_ops(self):
        num = 1
        for i in range(len(self.data.shape)-3):
            num *= self.data.shape[i]

        cout = self.output_loss[0].shape[-3]
        cin = self.data.shape[-3]
        hout = self.output_loss[0].shape[-2]
        wout = self.output_loss[0].shape[-1]

        hfil = self.weights.shape[-2]
        wfil = self.weights.shape[-1]

        mul = (hout * wout * \
                cout * cin * hfil * wfil * \
                num) / self.group

        add = (hout * wout * \
                num) / self.group

        # return {Ops.MUL: mul, Ops.ADD: add}
        dtypes = (self.output_loss[0].dtype, self.data.dtype, self.output_tensors.dtype)
        return {Ops.MAC(dtypes): mul}

class MaxPooling(NodeOp):
    def __init__(self, data, pooling_kernel, node_name, pad='VALID', stride=None, dtype=None):

        # Input data >3D
        self.data = data

        # Pooling kernel
        assert len(pooling_kernel) == len(data.shape)
        self.pooling_kernel = pooling_kernel

        # Stride
        if len(stride) == 1:
            stride = (1, stride, stride, 1)
        self.stride = stride

        if pad == 'VALID':
            self.pad = (
                    (0,0),
                    (0,0),
                    (0,0),
                    (0,0))
        elif pad == 'SAME':
            w = self.data.shape[-2]
            h = self.data.shape[-3]
            pad_w = (w - 1) * self.stride[-2] - w + self.pooling_kernel[-2]
            pad_h = (h - 1) * self.stride[-3] - h + self.pooling_kernel[-3]
            pad_w_l = pad_w // 2
            pad_w_r = pad_w - pad_w_l
            pad_h_t = pad_h // 2
            pad_h_b = pad_h - pad_h_t
            self.pad = (
                    (0,0),
                    (pad_h_t,pad_h_b),
                    (pad_w_l,pad_w_r),
                    (0,0))
        else:
            _pad = []
            assert len(pad) == 4 or len(pad) == 2
            for i in range(len(pad)):
                if isinstance(pad[i], int):
                    _pad.append((pad[i],pad[i]))
                else:
                    assert len(pad[i]) == 2
                    _pad.append(tuple(pad[i]))
            self.pad = _pad

        input_tensors = (data)
        if dtype is None:
            dtype = self.data.dtype
        self.dtype=dtype
        super(MaxPooling, self).__init__(node_name=node_name, input_tensors=input_tensors)

    def _get_output_shape(self):
        cout = self.data.shape[-1]
        hout = (self.data.shape[-3] - self.pooling_kernel[-3] + self.pad[-3][0] + self.pad[-3][1]) // self.stride[-3] + 1
        wout = (self.data.shape[-2] - self.pooling_kernel[-2] + self.pad[-2][0] + self.pad[-2][1]) // self.stride[-2] + 1
        out_shape = []
        for i in range(len(self.data.shape)-3):
            out_shape.append(self.data.shape[i])
        out_shape.append(hout)
        out_shape.append(wout)
        out_shape.append(cout)
        return tuple(out_shape)

    def _get_output_dtype(self):
        return self.data.dtype

    def _autograd(self, x, y, grad_dtype=FQDtype.FP32):
        self.output_loss = self._get_incoming_gradients(y, grad_dtype=grad_dtype)

        if self.input_loss[0] is None:
            op = MaxPoolBackprop(data=self.data, pooling_kernel=self.pooling_kernel, output_loss=self.output_loss, node_name=self.name)
            self.input_loss[0] = op.output_tensors

        assert x in self.input_tensors, 'Op: {}, x: {}'.format(self.name, x.name)
        return self.input_loss[0]

    def get_ops(self):
        num = 1
        for i in range(len(self.output_tensors.shape)-3):
            num *= self.data.shape[i]

        cout = self.output_tensors.shape[-3]
        hout = self.output_tensors.shape[-2]
        wout = self.output_tensors.shape[-1]

        hfil = self.pooling_kernel[-2]
        wfil = self.pooling_kernel[-1]

        CMP = hfil * wfil *\
                hout * wout * cout *\
                num

        dtypes = (self.data.dtype)
        return {Ops.CMP(dtypes): CMP}

class MaxPoolBackprop(GradOp):
    def __init__(self, data, output_loss, pooling_kernel, node_name, dtype=None):
        self.data = data
        self.output_loss = output_loss
        self.pooling_kernel = pooling_kernel
        input_tensors = (self.output_loss)
        node_name = self.data.name + '-backprop'
        if dtype is None:
            dtype = self.output_loss.dtype
        self.dtype=dtype
        super(MaxPoolBackprop, self).__init__(node_name=node_name, input_tensors=input_tensors)

    def _get_output_shape(self):
        return self.data.shape

    def get_ops(self):
        num = 1
        for i in range(len(self.output_tensors.shape)-3):
            num *= self.data.shape[i]

        cin = self.data.shape[-3]
        hin = self.data.shape[-2]
        win = self.data.shape[-1]

        hfil = self.pooling_kernel[-2]
        wfil = self.pooling_kernel[-1]

        CMP = hfil * wfil * \
                hin * win * cin * \
                num

        dtypes = (self.data.dtype)
        return {Ops.CMP(dtypes): CMP}

class Flatten(NodeOp):
    def __init__(self, data, node_name):

        # Input data >3D
        self.data = data

        input_tensors = data
        super(Flatten, self).__init__(node_name=node_name, input_tensors=input_tensors)

    def _get_output_shape(self):
        cout = self.data.shape[-3]
        hout = self.data.shape[-2]
        wout = self.data.shape[-1]
        out_shape = []
        for i in range(len(self.data.shape)-3):
            out_shape.append(self.data.shape[i])
        out_shape.append(cout*hout*wout)
        return tuple(out_shape)

    def _autograd(self, x, y, grad_dtype=FQDtype.FP32):
        self.output_loss = self._get_incoming_gradients(y, grad_dtype=grad_dtype)
        if self.input_loss[0] is None:
            op = FlattenBackprop(data=self.data, output_loss=self.output_loss, node_name=self.name, dtype=grad_dtype)
            self.input_loss[0] = op.output_tensors

        assert x in self.input_tensors, 'Op: {}, x: {}'.format(self.name, x.name)
        return self.input_loss[0]

    def _get_output_dtype(self):
        return self.data.dtype

    def get_ops(self):
        return {}

class FlattenBackprop(GradOp):
    def __init__(self, data, output_loss, node_name, dtype=None):
        self.data = data
        self.output_loss = output_loss
        input_tensors = (self.output_loss)
        node_name = self.data.name + '-backprop'
        self.dtype=dtype
        super(FlattenBackprop, self).__init__(node_name=node_name, input_tensors=input_tensors)

    def _get_output_shape(self):
        return self.data.shape

    def get_ops(self):
        return {}

class Concat(NodeOp):
    def __init__(self, data, concat_dim, node_name, dtype=None):

        self.data = tuple(data)
        input_tensors = data

        if concat_dim < 0:
            concat_dim += len(input_tensors[0].shape)

        for _data in data:
            assert len(_data.shape) == len(data[0].shape)
            for dim in range(len(_data.shape)):
                if dim != concat_dim:
                    assert _data.shape[dim] == data[0].shape[dim], '{} does not match {} for dimension {}'.format(data[0].__str__(), _data.__str__(), dim)

        self.concat_dim = concat_dim

        if dtype is None:
            dtype = data[0].dtype

        self.dtype=dtype
        super(Concat, self).__init__(node_name=node_name, input_tensors=input_tensors)

    def _get_output_shape(self):
        concat_dim = 0
        for _data in self.data:
            concat_dim += _data.shape[self.concat_dim]
        out_shape = []
        for i in range(len(self.data[0].shape)):
            if i == self.concat_dim:
                out_shape.append(concat_dim)
            else:
                out_shape.append(self.data[0].shape[i])
        return tuple(out_shape)

    def _get_output_dtype(self):
        return self.data[0].dtype

    def _autograd(self, x, y, grad_dtype=FQDtype.FP32):
        self.output_loss = self._get_incoming_gradients(y, grad_dtype=grad_dtype)
        assert x in self.data, 'Op: {}, x: {}'.format(self.name, x.name)
        for i in range(len(self.data)):
            if x == self.data[i]:
                if self.input_loss[i] is None:
                    op = ConcatBackprop(data=self.data[i], output_loss=self.output_loss, node_name=self.name, dtype=grad_dtype)
                    self.input_loss[i] = op.output_tensors
                return self.input_loss[i]


    def get_ops(self):
        return {}

class ConcatBackprop(GradOp):
    def __init__(self, data, output_loss, node_name, dtype=None):
        self.data = data
        self.output_loss = output_loss
        input_tensors = (self.output_loss)
        node_name = self.data.name + '-backprop'
        self.dtype=dtype
        super(ConcatBackprop, self).__init__(node_name=node_name, input_tensors=input_tensors)

    def _get_output_shape(self):
        return self.data.shape

    def get_ops(self):
        return {}

class Add(NodeOp):
    def __init__(self, data, node_name, dtype=None):

        self.data = tuple(data)
        input_tensors = data

        for _data in data:
            assert len(_data.shape) == len(data[0].shape)
            for dim in range(len(_data.shape)):
                assert _data.shape[dim] == data[0].shape[dim], '{} does not match {} for dimension {}'.format(data[0].__str__(), _data.__str__(), dim)


        if dtype is None:
            dtype = data[0].dtype

        self.dtype=dtype
        super(Add, self).__init__(node_name=node_name, input_tensors=input_tensors)

    def _get_output_shape(self):
        return self.data[0].shape

    def _get_output_dtype(self):
        return self.data[0].dtype

    def _autograd(self, x, y, grad_dtype=FQDtype.FP32):
        self.output_loss = self._get_incoming_gradients(y, grad_dtype=grad_dtype)
        assert x in self.data, 'Op: {}, x: {}'.format(self.name, x.name)
        for i in range(len(self.data)):
            if x == self.data[i]:
                if self.input_loss[i] is None:
                    op = AddBackprop(data=self.data[i], output_loss=self.output_loss, node_name=self.name, dtype=grad_dtype)
                    self.input_loss[i] = op.output_tensors
                return self.input_loss[i]


    def get_ops(self):
        return {}

class AddBackprop(GradOp):
    def __init__(self, data, output_loss, node_name, dtype=None):
        self.data = data
        self.output_loss = output_loss
        input_tensors = (self.output_loss)
        node_name = self.data.name + '-backprop'
        self.dtype=dtype
        super(AddBackprop, self).__init__(node_name=node_name, input_tensors=input_tensors)

    def _get_output_shape(self):
        return self.data.shape

    def get_ops(self):
        return {}

class MatMul(NodeOp):
    def __init__(self, data, weights, biases, name, dtype=None):

        # Input data >3D
        self.data = data

        # Weights data 2D
        self.weights = weights
        assert len(self.weights.shape) == 2
        assert self.weights.shape[-1] == self.data.shape[-1], 'Dimension mismatch between data ({}) and weights ({})'.format(self.data, self.weights)

        # Biases data 2D
        self.biases = biases
        assert len(self.biases.shape) == 1
        assert self.biases.shape[0] == self.weights.shape[-2]

        input_tensors = (data, weights, biases)
        super(MatMul, self).__init__(node_name=name, input_tensors=input_tensors)

    def _get_output_shape(self):
        cout = self.weights.shape[-2]
        out_shape = []
        for i in range(len(self.data.shape)-1):
            out_shape.append(self.data.shape[i])
        out_shape.append(cout)
        return tuple(out_shape)

    def _get_output_dtype(self):
        total_bits = 64
        total_frac_bits = self.data.dtype.frac_bits + self.weights.dtype.frac_bits
        return FixedPoint(total_bits, total_frac_bits)

    def _autograd(self, x, y, grad_dtype=FQDtype.FP32):
        self.output_loss = self._get_incoming_gradients(y, grad_dtype=grad_dtype)

        assert x in self.input_tensors, 'Op: {}, x: {}'.format(self.name, x.name)
        if x == self.data:
            if self.input_loss[0] is None:
                op = MatMulBackprop(data=self.data, weights=self.weights, output_loss=self.output_loss, node_name=self.name, dtype=grad_dtype)
                self.input_loss[0] = op.output_tensors
            return self.input_loss[0]
        else:
            if self.input_loss[1] is None:
                op = MatMulGradient(data=self.data, weights=self.weights, output_loss=self.output_loss, node_name=self.name, dtype=grad_dtype)
                self.input_loss[1] = op.output_tensors

            return self.input_loss[1]

    def get_ops(self):
        num = 1
        for i in range(len(self.data.shape)-1):
            num *= self.data.shape[i]

        cout = self.output_tensors.shape[-1]
        cin = self.data.shape[-1]

        mac = cin * \
                cout * \
                num

        dtypes = (self.data.dtype, self.weights.dtype, self.output_tensors.dtype)
        return {Ops.MAC(dtypes): mac}

class MatMulBackprop(GradOp):
    def __init__(self, data, weights, output_loss, node_name, dtype=None):
        self.data = data
        self.weights = weights
        self.output_loss = output_loss
        input_tensors = (self.output_loss, self.weights)
        node_name = node_name + '-backprop'
        super(MatMulBackprop, self).__init__(node_name=node_name, input_tensors=input_tensors)

    def _get_output_shape(self):
        return self.data.shape

    def get_ops(self):
        num = 1
        for i in range(len(self.data.shape)-1):
            num *= self.data.shape[i]

        cout = self.output_loss[0].shape[-1]
        cin = self.data.shape[-1]

        mac = cin * \
                cout * \
                num

        dtypes = (self.output_loss[0].dtype, self.data.dtype, self.output_tensors.dtype)
        return {Ops.MAC(dtypes): mac}

class MatMulGradient(GradOp):
    def __init__(self, data, weights, output_loss, node_name, dtype=None):
        self.data = data
        self.weights = weights
        self.output_loss = output_loss
        input_tensors = (self.output_loss, self.data)
        node_name = self.weights.name + '-grad'
        self.dtype=dtype
        super(MatMulGradient, self).__init__(node_name=node_name, input_tensors=input_tensors)

    def _get_output_shape(self):
        return self.weights.shape

    def get_ops(self):
        num = 1
        for i in range(len(self.data.shape)-1):
            num *= self.data.shape[i]

        cout = self.output_loss[0].shape[-1]
        cin = self.data.shape[-1]

        mul = cin * \
                cout * \
                num

        add = num

        # return {Ops.MUL: mul, Ops.ADD: add}
        dtypes = (self.output_loss[0].dtype, self.data.dtype, self.output_tensors.dtype)
        return {Ops.MAC(dtypes): mul}

class AddBias(NodeOp):
    def __init__(self, data, weights, dim, node_name, dtype=FQDtype.FP32):

        # Input data
        self.data = data

        # Bias data is 1D
        self.weights = weights
        if isinstance(weights.shape, int):
            assert weights.shape == data.shape[dim]
        else:
            assert len(self.weights.shape) == 1
            assert self.data.shape[dim] == weights.shape[0]

        self.dim=dim

        input_tensors = (data, weights)
        self.dtype=dtype
        super(AddBias, self).__init__(node_name=node_name, input_tensors=input_tensors)

    def _get_output_shape(self):
        return self.data.shape

    def _autograd(self, x, y, grad_dtype=FQDtype.FP32):
        self.output_loss = self._get_incoming_gradients(y, grad_dtype=grad_dtype)
        assert x in self.input_tensors, 'Op: {}, x: {}'.format(self.name, x.name)
        if x == self.data:
            if self.input_loss[0] is None:
                op = AddBiasBackprop(data=self.data, weights=self.weights, output_loss=self.output_loss, dim=self.dim, node_name=self.name, dtype=grad_dtype)
                self.input_loss[0] = op.output_tensors
            return self.input_loss[0]
        else:
            if self.input_loss[1] is None:
                op = AddBiasGradient(data=self.data, weights=self.weights, output_loss=self.output_loss, dim=self.dim, node_name=self.name, dtype=grad_dtype)
                self.input_loss[1] = op.output_tensors
            return self.input_loss[1]

    def get_ops(self):
        num = 1
        for i in range(len(self.data.shape)):
            num *= self.data.shape[i]

        add = num

        dtypes = (self.data.dtype, self.weights.dtype)
        return {Ops.ADD(dtypes): add}

class AddBiasBackprop(GradOp):
    def __init__(self, data, weights, output_loss, dim, node_name, dtype=None):

        # Input data
        self.data = data

        # Bias data is 1D
        self.weights = weights

        # Output loss
        self.output_loss = output_loss

        if isinstance(weights.shape, int):
            assert weights.shape == data.shape[dim]
        else:
            assert len(self.weights.shape) == 1
            assert self.data.shape[dim] == weights.shape[0]

        input_tensors = (output_loss, weights)
        node_name = self.weights.name + '-backprop'
        self.dtype=dtype
        super(AddBiasBackprop, self).__init__(node_name=node_name, input_tensors=input_tensors)

    def _get_output_shape(self):
        return self.data.shape

    def get_ops(self):
        return {}

class AddBiasGradient(GradOp):
    def __init__(self, data, weights, output_loss, dim, node_name, dtype=None):

        # Input data
        self.data = data

        # Bias data is 1D
        self.weights = weights

        # Output loss
        self.output_loss = output_loss

        self.dim = dim

        if isinstance(weights.shape, int):
            assert weights.shape == data.shape[dim]
        else:
            assert len(self.weights.shape) == 1
            assert self.data.shape[dim] == weights.shape[0]

        input_tensors = (output_loss, data)
        node_name = self.weights.name + '-grad'
        self.dtype=dtype
        super(AddBiasGradient, self).__init__(node_name=node_name, input_tensors=input_tensors)

    def _get_output_shape(self):
        return self.weights.shape

    def get_ops(self):
        num = 1
        for i in range(len(self.data.shape)):
            if i != self.dim:
                num *= self.data.shape[i]

        add = num

        dtypes = (self.output_loss.dtype, self.data.dtype)
        return {Ops.ADD(dtypes): add}


class GlobalAvgPooling(NodeOp):
    def __init__(self, data, node_name, dtype=None):
        # Input data >3D
        assert len(data.shape) > 3, data
        self.data = data
        input_tensors = data
        if dtype is None:
            dtype = data.dtype
        self.dtype=dtype
        super(GlobalAvgPooling, self).__init__(node_name=node_name, input_tensors=input_tensors)

    def _get_output_shape(self):
        cout = self.data.shape[-3]
        out_shape = []
        for i in range(len(self.data.shape)-3):
            out_shape.append(self.data.shape[i])
        out_shape.append(cout)
        return tuple(out_shape)

    def _autograd(self, x, y, grad_dtype=FQDtype.FP32):
        self.output_loss = self._get_incoming_gradients(y, grad_dtype=grad_dtype)
        if self.input_loss[0] is None:
            op = FlattenBackprop(data=self.data, output_loss=self.output_loss, node_name=self.name, dtype=grad_dtype)
            self.input_loss[0] = op.output_tensors

        assert x in self.input_tensors, 'Op: {}, x: {}'.format(self.name, x.name)
        return self.input_loss[0]

    def get_ops(self):
        return {}

class GlobalAvgPoolingBackprop(GradOp):
    def __init__(self, data, output_loss, node_name, dtype=None):
        self.data = data
        self.output_loss = output_loss
        input_tensors = (self.output_loss)
        node_name = self.data.name + '-backprop'
        self.dtype=dtype
        super(GlobalAvgPoolingBackprop, self).__init__(node_name=node_name, input_tensors=input_tensors)

    def _get_output_shape(self):
        return self.data.shape

    def get_ops(self):
        return {}

class AddScalar(NodeOp):
    def __init__(self, data, scalar, node_name, dtype=None):
        self.data = data
        self.scalar = scalar
        assert len(scalar.shape) == 1
        assert scalar.shape[0] == 1
        input_tensors = (data, scalar)
        self.dtype=dtype
        super(AddScalar, self).__init__(node_name=node_name, input_tensors=input_tensors)

    def _get_output_shape(self):
        return self.data.shape

    def get_ops(self):
        raise ValueError
        return {}

class MulScalar(NodeOp):
    def __init__(self, data, scalar, node_name, dtype=None):
        self.data = data
        self.scalar = scalar
        assert len(scalar.shape) == 1
        assert scalar.shape[0] == 1
        input_tensors = (data, scalar)
        self.dtype=dtype
        super(MulScalar, self).__init__(node_name=node_name, input_tensors=input_tensors)

    def _get_output_shape(self):
        return self.data.shape

    def get_ops(self):
        raise ValueError
        return {}

class InverseTensor(NodeOp):
    def __init__(self, data, node_name, dtype=None):
        self.data = data
        input_tensors = (data)
        self.dtype=dtype
        super(InverseTensor, self).__init__(node_name=node_name, input_tensors=input_tensors)

    def _get_output_shape(self):
        return self.data.shape

    def get_ops(self):
        raise ValueError
        return {}

class SubVector(NodeOp):
    def __init__(self, data, vector, dim, node_name, dtype=FQDtype.FP32):

        # Input data
        self.data = data

        # Bias data is 1D
        self.vector = vector
        if isinstance(vector.shape, int):
            assert vector.shape == data.shape[dim]
        else:
            assert len(self.vector.shape) == 1
            assert self.data.shape[dim] == vector.shape[0]

        self.dim=dim

        input_tensors = (data, vector)
        self.dtype=dtype
        super(SubVector, self).__init__(node_name=node_name, input_tensors=input_tensors)

    def _get_output_shape(self):
        return self.data.shape

    def get_ops(self):
        raise ValueError
        return {}

class MulVector(NodeOp):
    def __init__(self, data, vector, dim, node_name, dtype=FQDtype.FP32):

        # Input data
        self.data = data

        # Bias data is 1D
        self.vector = vector
        if isinstance(vector.shape, int):
            assert vector.shape == data.shape[dim]
        else:
            assert len(self.vector.shape) == 1
            assert self.data.shape[dim] == vector.shape[0]

        self.dim=dim

        input_tensors = (data, vector)
        self.dtype=dtype
        super(MulVector, self).__init__(node_name=node_name, input_tensors=input_tensors)

    def _get_output_shape(self):
        return self.data.shape

    def get_ops(self):
        raise ValueError
        return {}

class LeakyReLU(NodeOp):
    def __init__(self, data, scalar, node_name, dtype=None):
        self.data = data
        self.scalar = scalar
        assert len(scalar.shape) == 1
        assert scalar.shape[0] == 1
        input_tensors = (data, scalar)
        self.dtype=dtype
        super(LeakyReLU, self).__init__(node_name=node_name, input_tensors=input_tensors)

    def _get_output_shape(self):
        return self.data.shape

    def _get_output_dtype(self):
        return self.data.dtype

    def get_ops(self):
        mul_dtypes = (self.data.dtype, FixedPoint(16, 15))
        rshift_dtype = FixedPoint(self.data.dtype.bits + 16, self.data.dtype.frac_bits + 15)
        cmp_dtypes = (self.data.dtype)
        return {Ops.MUL(mul_dtypes): self.data.size,
                Ops.RSHIFT(rshift_dtype): self.data.size,
                Ops.CMP(cmp_dtypes): self.data.size}

class Maximum(NodeOp):
    def __init__(self, data, node_name, dtype=FQDtype.FP32):

        # Input data
        assert len(data) > 1

        s0 = data[0].shape
        for t in data:
            s = t.shape
            assert len(s0) == len(s)
            for d in range(len(s)):
                assert s[d] == s0[d]

        input_tensors = data
        self.dtype=dtype
        super(Maximum, self).__init__(node_name=node_name, input_tensors=input_tensors)

    def _get_output_shape(self):
        return self.input_tensors[0].shape

    def get_ops(self):
        raise ValueError
        return {}

class Reorg(NodeOp):
    def __init__(self, data, reorg_kernel, node_name, dtype=None):

        # Input data >3D
        self.data = data

        # Reorg kernel
        if isinstance(reorg_kernel, int):
            reorg_kernel = (reorg_kernel, reorg_kernel)
        self.reorg_kernel = reorg_kernel

        input_tensors = (data)
        if dtype is None:
            dtype = self.data.dtype
        self.dtype=dtype
        super(Reorg, self).__init__(node_name=node_name, input_tensors=input_tensors)

    def _get_output_shape(self):
        cout = self.data.shape[-3] * self.reorg_kernel[-1] * self.reorg_kernel[-2]
        hout = (self.data.shape[-2]) // self.reorg_kernel[-2]
        wout = (self.data.shape[-1]) // self.reorg_kernel[-1]
        out_shape = []
        for i in range(len(self.data.shape)-3):
            out_shape.append(self.data.shape[i])
        out_shape.append(cout)
        out_shape.append(hout)
        out_shape.append(wout)
        return tuple(out_shape)

    def get_ops(self):
        return {}

class BatchNorm(NodeOp):
    def __init__(self, data, mean, scale, eps, node_name, dtype=FQDtype.FP32):

        # Input data
        self.data = data

        # Channel
        dim = -1

        # Mean data is 1D
        self.mean = mean
        if isinstance(mean.shape, int):
            assert mean.shape == data.shape[dim]
        else:
            assert len(self.mean.shape) == 1
            assert self.data.shape[dim] == mean.shape[0]

        # Scale data is 1D
        self.scale = scale
        if isinstance(scale.shape, int):
            assert scale.shape == data.shape[dim]
        else:
            assert len(self.scale.shape) == 1
            assert self.data.shape[dim] == scale.shape[0]

        self.dim = dim
        self.eps = eps

        input_tensors = (data, mean, scale)
        self.dtype=dtype
        super(BatchNorm, self).__init__(node_name=node_name, input_tensors=input_tensors)

    def _get_output_shape(self):
        return self.data.shape

    def _get_output_dtype(self):
        return FixedPoint(32, self.data.dtype.frac_bits + self.scale.dtype.frac_bits)

    def get_ops(self):
        ops = self.data.size
        sub_dtypes = (self.data.dtype, self.mean.dtype)
        mul_dtypes = (self.data.dtype, self.scale.dtype)
        return {Ops.SUB(sub_dtypes): ops, Ops.MUL(sub_dtypes): ops}

    def load_params(self, params):
        self.mean.data = params["mean"]
        self.scale.data = params["scale"]

def typecast(i, dtype, name=None):
    if dtype is None or i.dtype == dtype:
        return i
    else:
        return TypeCastOp(i, dtype).output_tensors

def addBias(i, b, dim, name=None, dtype=None):
    g = get_default_graph()
    op = AddBias(i, b, dim, name, dtype=dtype)
    return typecast(op.output_tensors, dtype)

def conv2D(i, w, b, name=None, stride=None, pad='SAME', group=1, dtype=None):
    g = get_default_graph()
    op = Convolution(i, w, b, name, stride=stride, pad=pad, group=group, dtype=dtype)
    return typecast(op.output_tensors, dtype)

def maxPool(i, pooling_kernel, stride=(1,2,2,1), pad='VALID', name=None, dtype=None):
    g = get_default_graph()
    op = MaxPooling(i, pooling_kernel, name, stride=stride, pad=pad, dtype=dtype)
    return typecast(op.output_tensors, dtype)

def flatten(i, name=None, dtype=None):
    g = get_default_graph()
    op = Flatten(i, name)
    return typecast(op.output_tensors, dtype)

def matmul(i, w, b, name=None, dtype=None):
    g = get_default_graph()
    op = MatMul(i, w, b, name=name, dtype=dtype)
    return typecast(op.output_tensors, dtype)

def concat(data, concat_dim, name=None, dtype=None):
    op = Concat(data, concat_dim, name, dtype=dtype)
    return typecast(op.output_tensors, dtype)

def add(data, name=None, dtype=None):
    op = Add(data, name, dtype=dtype)
    return typecast(op.output_tensors, dtype)

def globalAvgPool(data, name=None, dtype=None):
    op = GlobalAvgPooling(data, name, dtype=dtype)
    return typecast(op.output_tensors, dtype)

def batch_norm(data, mean, scale, eps=0.000001, name=None, dtype=None):
    op = BatchNorm(data, mean, scale, eps=eps, node_name=name, dtype=dtype)
    return typecast(op.output_tensors, dtype)

def leakyReLU(data, name=None, alpha=0.1, dtype=None):
    if not isinstance(alpha, Tensor):
        alpha = get_tensor(shape=(1), name='alpha', data=alpha)
    op = LeakyReLU(data, alpha, node_name=None)
    return typecast(op.output_tensors, dtype)

def reorg(data, reorg_kernel, name=None, dtype=None):
    op = Reorg(data, reorg_kernel, name, dtype=dtype)
    return typecast(op.output_tensors, dtype)
