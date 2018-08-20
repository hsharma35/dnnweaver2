** NOTE **

DnnWeaver v2.0 applies the add_bias layer before batch normalization, as opposed to the software tensorflow implementation.

The add-bias layer adds a bias tensor to the input tensor as follows:
  tensor_out = tensor_in + bias
The batch-normalization layer does the following:
  tensor_out = (tensor_in - mean) * scale
, where scale is gamma/sqrt(0.00001 + variance)

To switch the order of the two layers, we simply divide the bias with the scale:
  bias_dnnweaver = bias / scale
