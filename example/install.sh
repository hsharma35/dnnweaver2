sudo apt-get install -y python-dev python-virtualenv pkg-config
sudo sudo apt-get install -y libavformat-dev libavcodec-dev libavdevice-dev libavutil-dev libswscale-dev libavresample-dev
sudo add-apt-repository ppa:jonathonf/ffmpeg-3
sudo apt-get install ffmpeg
sudo apt-get install --only-upgrade ffmpeg
sudo apt-get install -y graphviz
pip2.7 install --upgrade --user av cython image pandas graphviz opencv-python
pip2.7 install --upgrade --user --ignore-installed https://storage.googleapis.com/tensorflow/linux/cpu/tensorflow-1.10.0-cp27-none-linux_x86_64.whl
git clone https://github.com/thtrieu/darkflow.git
cd darkflow
pip2.7 uninstall -y darkflow
python2.7 setup.py build_ext --inplace
pip2.7 install --upgrade --user -e .
pip2.7 install --upgrade --user .
cd ..
git clone https://github.com/hanyazou/TelloPy.git
cd TelloPy
python2.7 setup.py bdist_wheel
pip2.7 uninstall -y tellopy
pip2.7 install --upgrade --user dist/tellopy*.whl
