import importlib

benchmark_list = [\
                  'alexnet-d',
                  'alexnet-q',
                  'alexnet-w',
                  'googlenet-q',
                  'resnet-34-w',
                  'svhn-d',
                  'svhn-q',
                  'cifar-10-q'
                 ]

def get_graph(bench, train=True):
    bench = bench.lower()
    module_name = 'dnnweaver2.benchmarks.' + bench
    # print(module_name)
    b = importlib.import_module(module_name)
    return b.get_graph(train=train)
