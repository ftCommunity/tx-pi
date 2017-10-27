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
ldconfig

# install python
make python

#udev rules
cp udev/fischertechnik.rules /etc/udev/rules.d/

# python3 compatibility 'patch'
cd ..
wget -N https://github.com/PeterDHabermehl/libroboint-py3/raw/master/robointerface.py
mv robointerface.py /usr/local/lib/python3.4/dist-packages/


# clean up
rm -f $LIBFILE
rm -fr $IDIR

echo "====================================================="
echo "                libroboint finished"
echo "====================================================="
