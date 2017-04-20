#!/bin/bash

LIBURL=https://github.com/nxdefiant/libroboint/archive/
LIBFILE=0.5.3.zip
IDIR=libroboint-0.5.3

echo "====================================================="
echo "       downloading and building of libroboint "
echo "====================================================="

# download libroboint sources
wget -N $LIBURL$LIBFILE
unzip $LIBFILE

# install libusb-dev
apt-get install libusb-dev

# build
cd $IDIR
cmake .
make
make doc

# install
make install

# install python
make python

#udev rules
cp udev/fischertechnik.rules /etc/udev/rules.d/

# python3 compatibility 'patch'
# .pyc was temporarily disabled since it's not working
cd ..
wget -N https://github.com/PeterDHabermehl/libroboint-py3/raw/master/robointerface.py
#wget https://github.com/PeterDHabermehl/libroboint-py3/raw/master/robointerface.pyc
mv robointerface.py /usr/local/lib/python3.4/dist-packages/
#mv robointerface.pyc /usr/local/lib/python3.4/dist-packages/
rm -f /usr/local/lib/python3.4/dist-packages/robointerface.pyc

# clean up
rm -f $LIBFILE
rm -fr $IDIR

echo "====================================================="
echo "                libroboint finished"
echo "====================================================="
