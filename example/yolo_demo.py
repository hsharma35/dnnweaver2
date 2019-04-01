import sys
import pickle
import os
import cv2 as cv2
import collections
import numpy as np
import copy
import logging
import collections
from time import time
from darkflow.net.build import TFNet

sys.path.append('..')
from yolo_tf.yolo2_tiny_tf import YOLO2_TINY_TF
from dnn_fpga import dnn_fpga

def get_bbox(tfnet, box_input, h, w):
    boxes = tfnet.framework.findboxes(box_input)

    threshold = tfnet.FLAGS.threshold
    boxesInfo = list()
    for box in boxes:
        tmpBox = tfnet.framework.process_box(box, h, w, threshold)
        if tmpBox is None:
            continue
        boxesInfo.append({
            "label": tmpBox[4],
            "confidence": tmpBox[6],
            "topleft": {
                "x": tmpBox[0],
                "y": tmpBox[2]},
            "bottomright": {
                "x": tmpBox[1],
                "y": tmpBox[3]}
        })
    return boxesInfo

def fp32tofxp16_tensor(tensor, num_frac_bits):
    pow_nfb_tensor = np.full(tensor.shape, pow(2, num_frac_bits), dtype=np.int32)
    shifted_tensor = tensor * pow_nfb_tensor
    casted_tensor = np.int16(shifted_tensor)
    return casted_tensor

def fxp16tofp32_tensor(tensor, num_frac_bits):
    pow_nfb_tensor = np.full(tensor.shape, np.float32(pow(2, num_frac_bits)), dtype=np.float32)
    shifted_tensor = np.float32(tensor) / pow_nfb_tensor
    return shifted_tensor

def run_tf(tin, tf_weight_pickle): 
    y2t_tf = YOLO2_TINY_TF([1, 416, 416, 3], tf_weight_pickle) 
    nodes, out_tensors = y2t_tf._inference(tin)
    out_tensors_d = collections.OrderedDict()
    cnt = 0
    for i in range(len(nodes)):
        node = nodes[i]
        if "Maximum" in node.name:
            if "Maximum_7" in node.name:
                out_tensors_d["conv7"] = out_tensors[i]
            else:
                out_tensors_d["conv" + str(cnt)] = out_tensors[i]
        if "MaxPool" in node.name:
            out_tensors_d["pool" + str(cnt)] = out_tensors[i]
            cnt += 1
        if "BiasAdd_8" in node.name:
            out_tensors_d["conv8"] = out_tensors[i]

    return out_tensors_d

def run_fpga(tin, bf_weight_pickle):

    out_tensors_d = collections.OrderedDict()
    fxp_out_tensors_d = collections.OrderedDict()
    _tin = fp32tofxp16_tensor(tin, 8)

    fpga_manager = dnn_fpga.initialize_yolo_graph(bf_weight_pickle)
    start = time()
    tout = dnn_fpga.fpga_inference(fpga_manager, _tin)
    end = time()
    fps = 1.0 / (end - start)
    fxp_tout = copy.deepcopy(tout)
    tout = fxp16tofp32_tensor(tout, fpga_manager.get_tout_frac_bits())
    out_tensors_d["conv8"] = [tout, fps, (end - start)]
    fxp_out_tensors_d["conv8"] = [fxp_tout, fps, (end - start)]

    return out_tensors_d, fxp_out_tensors_d

def main():
    if len(sys.argv) != 4:
        print ("Usage ./compare_fpga.py <input_png> <my-weight.pickle> <dnnweaver2-weight.pickle>")
        sys.exit()
    else:
        input_png = sys.argv[1]
        weight_pickle = sys.argv[2]
        bf_weight_pickle = sys.argv[3]

    options = {"model": "conf/tiny-yolo-voc.cfg", "load": "weights/tiny-yolo-voc.weights", "threshold": 0.25}
    tfnet = TFNet(options)

    input_im = cv2.imread(input_png, cv2.IMREAD_COLOR) 
    h, w, _ = input_im.shape
    im = tfnet.framework.resize_input(input_im)
    tin = np.expand_dims(im, 0)

    my_tin = copy.deepcopy(tin)
    fpga_tin = copy.deepcopy(tin)

    my_touts = run_tf(my_tin, weight_pickle)

    fpga_touts, fxp_fpga_touts = run_fpga(fpga_tin, bf_weight_pickle)

    for key in fpga_touts.keys():
        my_o = my_touts[key]
        fpga_o, fpga_fps, fpga_inference_time = fpga_touts[key]
        print ("layer ~" + str(key) + ": nrmse = %.8f%%\tFPS: %.1f\tInference time: %.2f sec" % (((np.sqrt(np.mean((my_o - fpga_o) ** 2))) / (my_o.max() - my_o.min()) * 100) ,fpga_fps,fpga_inference_time))

    result = get_bbox(tfnet, fpga_touts["conv8"][0][0], h, w)

    font = cv2.FONT_HERSHEY_SIMPLEX
    for det in result:
        label, l, r, t, b = det['label'], det['topleft']['x'], det['bottomright']['x'], det['topleft']['y'], det['bottomright']['y']
        cv2.rectangle(input_im, (l, b), (r, t), (0, 255, 0), 2)
        if "4.0.0" in cv2.__version__:
            cv2.putText(input_im, label, (l, b), font, 1, (255, 255, 255), 2, cv2.LINE_AA)
        elif "2.4.9.1" in cv2.__version__:
            cv2.putText(input_im, label, (l, b), font, 1, (255, 255, 255), 2, cv2.CV_AA)
        else:
            raise Exception("Unknown cv2 version")

    cv2.imwrite(os.path.join(os.path.dirname(input_png), "bbox-" + os.path.basename(input_png)), input_im)


if __name__ == '__main__':
    main()
