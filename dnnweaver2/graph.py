import logging
import pickle
import os
import sys

from graphviz import Digraph
from collections import OrderedDict, deque
from contextlib import contextmanager
from dnnweaver2.tensor import Tensor
from dnnweaver2.scalar.dtypes import Dtype, FQDtype, FixedPoint, Log, Binary, Float, CustomFloat
from dnnweaver2.utils.utils import lookup_pandas_dataframe

logging.basicConfig()

import pandas as pd
import os

class Graph(object):
    def __init__(self, name, dataset, log_level=logging.DEBUG):
        default_graph = self
        self.name = name
        self.dataset = dataset
        self.logger = logging.getLogger(name)
        self.logger.setLevel(log_level)
        self.tensor_registry = OrderedDict()
        self.tensor_id_counter = 0
        self.op_id_counter = 0
        self.op_registry = OrderedDict()
        self.op_type_counter = {}
        self.current_scope = ""
        self.scope_stack = deque([""])
        self.grad_dtype = FQDtype.FP32
        self.intermediate_dtype = FQDtype.FXP32
        
    def set_gradient_dtype(self, dtype):
        assert isinstance(dtype, Dtype)
        self.grad_dtype = dtype

    def get_dot(self):
        dot = Digraph()
        dot_node_dict = {}
        for opname, op in self.op_registry.items():
            dot_node_dict[op] = '{}\nshape={}\ndtype={}'.format(opname, op.output_tensors.shape, op.output_tensors.dtype)
        for opname, op in self.op_registry.items():            
            is_sink = len(op.output_tensors.output_nodes) == 0
            if is_sink:
                dot.node(dot_node_dict[op], fillcolor='pink', style='filled')
            else:
                dot.node(dot_node_dict[op], fillcolor='cyan', style='filled')
            for t in op.input_tensors:
                if t.op is None:
                    tensor_name = '{}\nshape = {}\ndtype = {}'.format(t.name,t.shape,t.dtype)
                    dot.node(tensor_name, shape='rectangle', fillcolor='gray', style='filled')
                    dot.edge(tensor_name, dot_node_dict[op])
                else:
                    dot.edge(dot_node_dict[t.op], dot_node_dict[op])
        return dot

    def tensor(self, shape, name=None, dtype=None, trainable=True, data=None):
        assert shape is not None, shape
        assert isinstance(shape, tuple) or isinstance(shape, int)
        if isinstance(shape, list):
            shape = tuple(shape)
        if name is None:
            name = str(self.tensor_id_counter)
            self.tensor_id_counter += 1
        name = '{}{}'.format(self.current_scope, name)
        assert name not in self.tensor_registry, 'Tensor with name {} already exists!'.format(name)
        t = Tensor(shape, name, data, dtype, trainable)
        self.tensor_registry[name] = t
        self.logger.debug('Created tensor {}'.format(t.__str__()))
        return t

    def register_tensor(self, t):
        assert t.name not in self.tensor_registry
        self.tensor_registry[t.name] = t

    def create_node(self, op):
        name = op.name
        name = '{}{}'.format(self.current_scope, name)
        op.name = name
        assert name not in self.op_registry, 'Op with name {} already exists!'.format(name)
        self.op_registry[name] = op

        for t in op.input_tensors:
            t.output_nodes.append(op)

        self.logger.debug('Created op {}'.format(op.name))
        return op.output_tensors

    def get_trainable_tensors(self):
        trainable_tensors = []
        for tname in self.tensor_registry:
            t = self.tensor_registry[tname]
            if t.trainable:
                trainable_tensors.append(t)
        return tuple(trainable_tensors)

    def set_graph_context(self, c):
        self.graph_context = c

    def as_default(self):
        return _default_graph_stack.get_controller(self)

    def get_op_dependencies(self, tensor):
        if tensor.op is None:
            return tuple([])
        deps = [tensor.op]
        for t in tensor.op.input_tensors:
            if t.op is not None:
                for op in self.get_op_dependencies(t):
                    deps.append(op)
        return tuple(deps)

    def get_tensor_dependencies(self, tensor):
        tlist = []
        for op in self.get_op_dependencies(tensor):
            for t in op.input_tensors:
                tlist.append(t)
        return tuple(tlist)

    def get_op_name(self, name, op_type):
        if op_type not in self.op_type_counter:
            self.op_type_counter[op_type] = 0

        if name is None:
            op_count = self.op_type_counter[op_type]
            if op_count == 0:
                name = op_type
            else:
                name = '{}:{}'.format(op_type, self.op_type_counter[op_type])

        self.op_type_counter[op_type] += 1
        return name

    def get_ops(self):
        total_ops = {}
        for opname, op in self.op_registry.items():
            for op_type, num_ops in op.get_ops().items():
                if op_type not in total_ops:
                    total_ops[op_type] = 0
                total_ops[op_type] += num_ops
        return total_ops

    @contextmanager
    def name_scope(self, name):
        current_scope = self.current_scope
        current_op_type_counter = self.op_type_counter.copy()
        if self.current_scope == "":
            next_scope = '{}/'.format(name)
        else:
            next_scope = '{}{}/'.format(self.current_scope, name)
        try:
            self.op_type_counter = {}
            self.current_scope = next_scope
            yield
        finally:
            self.op_type_counter = current_op_type_counter
            self.current_scope = current_scope
            
            
    def print_ops(self):
        total_ops = {}
        g = self
        for key, op in g.op_registry.items():
            sub_ops = op.get_ops()
            if len(sub_ops.keys()) > 0:
                for op, num in sub_ops.items():
                    sopname = op.__str__()
                    if sopname not in total_ops:
                        total_ops[sopname] = num
                    else:
                        total_ops[sopname] += num

        print('*'*100)
        for sop, num in total_ops.items():
            print('{:>80}: {:>20,}'.format(sop, num))
            
    def benchmark_tf(self, phase='forward+backward', csv_file='gpu_baseline.csv'):
        
        assert phase in ['forward', 'backward', 'forward+backward']
        
        if not os.path.exists(csv_file):
            gpu_df = pd.DataFrame(columns=['Platform', 'Phase', 'Benchmark', 'Time Mean (sec)', 'Time Standard Deviation (sec)', 'Power Mean (Watt)', 'Power Standard Deviation (Watt)'])
        else:        
            gpu_df = pd.read_csv(csv_file)
            
        r = lookup_pandas_dataframe(gpu_df, {'Benchmark': self.name, 'Phase': phase})
        
        if len(r) == 0:
            
            from dnnweaver2.tf_utils import get_tf_performance
            
            if phase == 'backward':
                print('backward')
                t_mn, t_sd, p_mn, p_sd = get_tf_performance(self, 'forward+backward')
                f_t_mn, f_t_sd, f_p_mn, f_p_sd = get_tf_performance(self, 'forward')
                t_mn -= f_t_mn
            elif phase == 'forward':
                print('forward')
                t_mn, t_sd, p_mn, p_sd = get_tf_performance(self, 'forward')
            else:
                print('forward+backward')
                t_mn, t_sd, p_mn, p_sd = get_tf_performance(self, 'forward+backward')
                
                
            data = [['TitanXp', phase, self.name, t_mn, t_sd, p_mn, p_sd]]
            current_df = pd.DataFrame(data, columns=['Platform', 'Phase', 'Benchmark', 'Time Mean (sec)', 'Time Standard Deviation (sec)', 'Power Mean (Watt)', 'Power Standard Deviation (Watt)'])
            gpu_df = pd.concat([gpu_df, current_df], ignore_index=True)
            gpu_df.to_csv(csv_file, index=False)
        else:
            t_mn = float(r['Time Mean (sec)'])
            t_sd = float(r['Time Standard Deviation (sec)'])
            p_mn = float(r['Power Mean (Watt)'])
            p_sd = float(r['Power Standard Deviation (Watt)'])
        return t_mn, t_sd, p_mn, p_sd

    def load_params_from_pickle(self, pickle_filename):
        with open(pickle_filename, "rb") as h:
            if "2.7" in sys.version:
            	params = pickle.load(h)
            elif "3.5" in sys.version:
                params = pickle.load(h, encoding='latin1')
            else:
                raise Exception("Unknown python version")

        for opname in params.keys():
            if opname in self.op_registry.keys():
                op = self.op_registry[opname]
                op.load_params(params[opname])


class GraphStack(object):
    def __init__(self):
        self.stack = deque([Graph('default', 'ilsvrc12')])
    @contextmanager
    def get_controller(self, default):
        try:
            self.stack.append(default)
            yield default
        finally:
            if self.stack:
                if self.stack[-1] is not default:
                    raise AssertionError('Error in nesting graph stacks')
                else:
                    self.stack.remove(default)
    def get_default(self):
        return self.stack[-1] if len(self.stack) >= 1 else None


_default_graph_stack = GraphStack()

def get_default_graph():
    return _default_graph_stack.get_default()
