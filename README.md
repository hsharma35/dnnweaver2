# DnnWeaver v2.0

**DnnWeaver v2.0** is an open-source framework for accelerating Deep Neural Networks (DNNs) on FPGAs.

## Citing us
If you use this work, please cite our paper published in The 49th Annual IEEE/ACM International Symposium on Microarchitecture (MICRO), 2016.

```
H. Sharma, J. Park, D. Mahajan, E. Amaro, J. K. Kim, C. Shao, A. Mishra, H. Esmaeilzadeh, "From High-Level Deep Neural Models to FPGAs", in the Proceedings of the 49th Annual IEEE/ACM International Symposium on Microarchitecture (MICRO), 2016.
```

## Build Instructions

Python dependencies:
```
pip install -r requirements.txt
```

Vivado Tool version:
```
Vivado 2018.2
```

## Examples
dnnweaver2-tutorial.ipynb provides a tutorial on how to use the tool

Dependencies:
```
darkflow (https://github.com/thtrieu/darkflow)
OpenCV (cv2)
```

Here's a sample project that uses DnnWeaver v2.0 to perform real-time image recognition with a drone
https://github.com/ardorem/dnnweaver2.drone


## License

```
Copyright 2018 Hadi Esmaeilzadeh

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
```

## Maintained By
Hardik Sharma (*hsharma@gatech.edu*)
