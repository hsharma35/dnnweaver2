import abc
from dnnweaver2.tensor import Tensor
from dnnweaver2.graph import get_default_graph
from dnnweaver2.scalar.dtypes import FQDtype

class NodeOp(object):
    __metaclass__ = abc.ABCMeta
    def __init__(self, node_name, input_tensors=None):
        self.graph = get_default_graph()
        self.op_type = self._get_op_type()
        self.name = self.graph.get_op_name(node_name, self.op_type)
        
        self.dtype = self._get_output_dtype()
            
        if isinstance (input_tensors, Tensor):
            input_tensors = tuple([input_tensors])
        else:
            it = []
            for _it in input_tensors:
                if isinstance(_it, tuple):
                    for __it in _it:
                        it.append(__it)
                else:
                    it.append(_it)
            input_tensors = tuple(it)
            
        # input_str = ','.join([x.__str__() for x in input_tensors])
        # print('## Creating op with name {} and inputs {}'.format(node_name, input_str))

        self.input_tensors = input_tensors
        self.output_tensors = self._create_output_tensors(self.name)
        
        self.input_loss = [None]*len(input_tensors)

        self.graph.create_node(self)
        
        self.incoming_gradients = None

    @abc.abstractmethod
    def _get_output_shape(self):
        pass
    
    @abc.abstractmethod
    def _get_output_dtype(self):
        pass
    
    def _create_output_tensors(self, name):
        out_name = name
        t = self.graph.tensor(self._get_output_shape(), out_name, dtype=self.dtype, trainable=False)
        t.op = self
        return t

    def _get_op_type(self):
        return self.__class__.__name__

    def _autograd(self, x, y):
        raise NotImplementedError('Backprop for class {} not implemented'.format(self.__class__.__name__))

    def _get_incoming_gradients(self, y, grad_dtype=FQDtype.FP32):
        if self.incoming_gradients is None:
            incoming_gradients = [op._autograd(self.output_tensors, y, grad_dtype=grad_dtype) for op in self.output_tensors.output_nodes if not isinstance(op, GradOp)]
            if len(incoming_gradients) > 1:
                op = AddGrad(incoming_gradients, self.name+'-addGrad', dtype=grad_dtype)
                incoming_gradients = [op.output_tensors]
            assert len(incoming_gradients) == 1, ' '.join([x.__str__() for x in incoming_gradients])
            self.incoming_gradients = tuple(incoming_gradients)
            return self.incoming_gradients
        else:
            return self.incoming_gradients

    @abc.abstractmethod
    def get_ops(self):
        pass

class GradOp(NodeOp):
    def __init__(self, node_name, dtype=None, input_tensors=None):
        if dtype is None:
            dtype = get_default_graph().grad_dtype
    
        super(GradOp, self).__init__(node_name, dtype, input_tensors)
        
    def _autograd(self, x, y, grad_dtype):
        raise ValueError('Cannot backpropagate using GradOp {}'.format(self.__class__.__name__))

class AddGrad(GradOp):
    def __init__(self, data, node_name, dtype=None):
        self.data = data
        input_tensors = data
        self.dtype=dtype
        super(AddGrad, self).__init__(node_name=node_name, input_tensors=input_tensors, dtype=dtype)

    def _get_output_shape(self):
        return self.data[0].shape

    def get_ops(self):
        return {}
