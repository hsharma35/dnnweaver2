import sys
from time import time
import numpy as np
import dnnweaver2.benchmarks
import dnnweaver2.benchmarks.yolo2_tiny
import dnnweaver2.compiler
import logging 
from dnnweaver2.fpga.fpgamanager import FPGAManager
import dnnweaver2.simulator.accelerator

def initialize_yolo_graph(weight_pickle, debug_mode=False):
    yolo_graph = dnnweaver2.benchmarks.get_graph('yolo2_tiny', train=False)

    fpga_spec = dnnweaver2.compiler.FPGASpec(num_ddr=1, size_ddr=1024, bandwidth_per_ddr=512)
    fpga_compiler = dnnweaver2.compiler.GraphCompiler(fpga_spec)

    sram ={
        'ibuf': 16*32*512,
        'wbuf': 16*32*32*512,
        'obuf': 64*32*512,
        'bbuf': 16*32*512
    }

    acc_obj = dnnweaver2.simulator.accelerator.Accelerator(N=32,M=32,prec=16,mem_if_width=256,frequency=100e6,sram=sram)
    inst_array = fpga_compiler.compile(graph=yolo_graph, acc_obj=acc_obj)

    fpga_manager = FPGAManager(pci_cl_ctrl_device="/dev/xdma0_user", c2h_dma_device="/dev/xdma0_c2h_0", h2c_dma_device="/dev/xdma0_h2c_0")
    fpga_manager.initialize_graph_tensors(yolo_graph)
    yolo_graph.load_params_from_pickle(weight_pickle)
    fpga_manager.write('pci_cl_data', 0, inst_array)
    fpga_manager.initialize_graph(yolo_graph, 32, 32)

    return fpga_manager

def get_input_tensor(input_npy):
    inp = np.load(input_npy)
    inp = np.expand_dims(inp, axis=0)
    return inp

def fpga_inference(fpga_manager, inp):
    fpga_manager.send_input_nparr(inp)
    fpga_manager.start()
    fpga_manager.wait_fpga_execution()
    onp = fpga_manager.recv_output_nparr()
    return onp
