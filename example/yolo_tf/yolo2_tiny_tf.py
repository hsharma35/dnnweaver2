import tensorflow as tf
import os
import sys
import pickle
import numpy as np
import tensorflow as tf
import cv2 as cv2

class YOLO2_TINY_TF(object):

    def __init__(self, in_shape, weight_pickle, proc="cpu"):
        self.g = tf.Graph()
        self.sess = tf.Session(graph=self.g)
        self.proc = proc
        self.weight_pickle = weight_pickle
        self.inp, self.nodes = self.build_graph(in_shape)

    def get_y2t_w(self):
        with open(self.weight_pickle, "rb") as h:
            if "2.7" in sys.version:
                y2t_w = pickle.load(h)
            elif "3.5" in sys.version:
                y2t_w = pickle.load(h, encoding='latin1')
            else:
                raise Exception("Unknown python version")
        return y2t_w

    def build_graph(self, in_shape):
        y2t_w   =   self.get_y2t_w()
        nodes   =   []

        with self.g.as_default(): 
            with tf.device('/' + self.proc + ':0'):

                inp     =   tf.placeholder(tf.float32, shape=in_shape, name="input")

                conv0   =   tf.nn.conv2d(inp, y2t_w[0]["kernel"], strides=[1, 1, 1, 1], padding='SAME')                                                 ;       nodes.append(conv0)
                bias0   =   tf.nn.bias_add(conv0, y2t_w[0]["biases"])                                                                                   ;       nodes.append(bias0)
                bn0     =   tf.nn.batch_normalization(bias0, y2t_w[0]["moving_mean"], y2t_w[0]["moving_variance"], None, y2t_w[0]["gamma"], 1e-5)       ;       nodes.append(bn0)
                l1      =   tf.maximum(bn0, .1 * bn0)                                                                                                   ;       nodes.append(l1)
                p2      =   tf.nn.max_pool(l1, ksize=[1, 2, 2, 1], strides=[1, 2, 2, 1], padding='SAME')                                                ;       nodes.append(p2)

                conv3   =   tf.nn.conv2d(p2, y2t_w[1]["kernel"], strides=[1, 1, 1, 1], padding='SAME')                                                  ;       nodes.append(conv3)
                bias3   =   tf.nn.bias_add(conv3, y2t_w[1]["biases"])                                                                                   ;       nodes.append(bias3)
                bn3     =   tf.nn.batch_normalization(bias3, y2t_w[1]["moving_mean"], y2t_w[1]["moving_variance"], None, y2t_w[1]["gamma"], 1e-5)       ;       nodes.append(bn3)
                l4      =   tf.maximum(bn3, .1 * bn3)                                                                                                   ;       nodes.append(l4)
                p5      =   tf.nn.max_pool(l4, ksize=[1, 2, 2, 1], strides=[1, 2, 2, 1], padding='SAME')                                                ;       nodes.append(p5)

                conv6   =   tf.nn.conv2d(p5, y2t_w[2]["kernel"], strides=[1, 1, 1, 1], padding='SAME')                                                  ;       nodes.append(conv6)
                bias6   =   tf.nn.bias_add(conv6, y2t_w[2]["biases"])                                                                                   ;       nodes.append(bias6)
                bn6     =   tf.nn.batch_normalization(bias6, y2t_w[2]["moving_mean"], y2t_w[2]["moving_variance"], None, y2t_w[2]["gamma"], 1e-5)       ;       nodes.append(bn6)
                l7      =   tf.maximum(bn6, .1 * bn6)                                                                                                   ;       nodes.append(l7)
                p8      =   tf.nn.max_pool(l7, ksize=[1, 2, 2, 1], strides=[1, 2, 2, 1], padding='SAME')                                                ;       nodes.append(p8)

                conv9   =   tf.nn.conv2d(p8, y2t_w[3]["kernel"], strides=[1, 1, 1, 1], padding='SAME')                                                  ;       nodes.append(conv9)
                bias9   =   tf.nn.bias_add(conv9, y2t_w[3]["biases"])                                                                                   ;       nodes.append(bias9)
                bn9     =   tf.nn.batch_normalization(bias9, y2t_w[3]["moving_mean"], y2t_w[3]["moving_variance"], None, y2t_w[3]["gamma"], 1e-5)       ;       nodes.append(bn9)
                l10     =   tf.maximum(bn9, .1 * bn9)                                                                                                   ;       nodes.append(l10)
                p11      =   tf.nn.max_pool(l10, ksize=[1, 2, 2, 1], strides=[1, 2, 2, 1], padding='SAME')                                              ;       nodes.append(p11)

                conv12  =   tf.nn.conv2d(p11, y2t_w[4]["kernel"], strides=[1, 1, 1, 1], padding='SAME')                                                 ;       nodes.append(conv12)
                bias12  =   tf.nn.bias_add(conv12, y2t_w[4]["biases"])                                                                                  ;       nodes.append(bias12)
                bn12    =   tf.nn.batch_normalization(bias12, y2t_w[4]["moving_mean"], y2t_w[4]["moving_variance"], None, y2t_w[4]["gamma"], 1e-5)      ;       nodes.append(bn12)
                l13     =   tf.maximum(bn12, .1 * bn12)                                                                                                 ;       nodes.append(l13)
                p14     =   tf.nn.max_pool(l13, ksize=[1, 2, 2, 1], strides=[1, 2, 2, 1], padding='SAME')                                               ;       nodes.append(p14)

                conv15  =   tf.nn.conv2d(p14, y2t_w[5]["kernel"], strides=[1, 1, 1, 1], padding='SAME')                                                 ;       nodes.append(conv15)
                bias15  =   tf.nn.bias_add(conv15, y2t_w[5]["biases"])                                                                                  ;       nodes.append(bias15)
                bn15    =   tf.nn.batch_normalization(bias15, y2t_w[5]["moving_mean"], y2t_w[5]["moving_variance"], None, y2t_w[5]["gamma"], 1e-5)      ;       nodes.append(bn15)
                l16     =   tf.maximum(bn15, .1 * bn15)                                                                                                 ;       nodes.append(l16)
                p17     =   tf.nn.max_pool(l16, ksize=[1, 2, 2, 1], strides=[1, 1, 1, 1], padding='SAME')                                               ;       nodes.append(p17)

                conv18  =   tf.nn.conv2d(p17, y2t_w[6]["kernel"], strides=[1, 1, 1, 1], padding='SAME')                                                 ;       nodes.append(conv18)
                bias18  =   tf.nn.bias_add(conv18, y2t_w[6]["biases"])                                                                                  ;       nodes.append(bias18)
                bn18    =   tf.nn.batch_normalization(bias18, y2t_w[6]["moving_mean"], y2t_w[6]["moving_variance"], None, y2t_w[6]["gamma"], 1e-5)      ;       nodes.append(bn18)
                l19     =   tf.maximum(bn18, .1 * bn18)                                                                                                 ;       nodes.append(l19)
                                                                                                                                                        
                conv20  =   tf.nn.conv2d(l19, y2t_w[7]["kernel"], strides=[1, 1, 1, 1], padding='SAME')                                                 ;       nodes.append(conv20)
                bias20  =   tf.nn.bias_add(conv20, y2t_w[7]["biases"])                                                                                  ;       nodes.append(bias20)
                bn20    =   tf.nn.batch_normalization(bias20, y2t_w[7]["moving_mean"], y2t_w[7]["moving_variance"], None, y2t_w[7]["gamma"], 1e-5)      ;       nodes.append(bn20)
                l21     =   tf.maximum(bn20, .1 * bn20)                                                                                                 ;       nodes.append(l21)

                conv22  =   tf.nn.conv2d(l21, y2t_w[8]["kernel"], strides=[1, 1, 1, 1], padding='SAME')                                                 ;       nodes.append(conv22)
                out     =   tf.nn.bias_add(conv22, y2t_w[8]["biases"])                                                                                  ;       nodes.append(out)
                                                                                                                                                        
                init    =   tf.global_variables_initializer()                                                                                           
                self.sess.run(init)

        return inp, nodes

    def _inference(self, im):
        feed_dict = {self.inp: im}
        out_tensors = self.sess.run(self.nodes, feed_dict)
        return self.nodes, out_tensors

    def inference(self, im, out_f=None):
        feed_dict = {self.inp: im}
        out_tensors = self.sess.run(self.nodes, feed_dict)
        out_tensors_d = {}
        for node_i in range(len(self.nodes)):
            nodename = self.nodes[node_i].name
            nodename = (nodename.split(":")[0]).split("/")[0]
            out_tensors_d[nodename] = out_tensors[node_i]
        if out_f != None:
            with open(out_f, "wb") as h:
                pickle.dump(out_tensors_d, h, protocol=2)
        return out_tensors[len(out_tensors) - 1]
