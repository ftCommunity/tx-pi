#!/bin/bash

# preparaion
# copy 2017-03-02-raspbian-jessie-lite.img to sd card
# set interfaces for eth0
# touch /boot/ssh
# -> boot pi
# raspi-config
#    hostname tx-pi
#    enable ssh
#    expand filesystem
#    disable wait for network

# TODO
# - add screen calibration tool
# - adjust timezone
# - fix wlan/eth
#   - don't wait for eth0
#   - control regular dhcpcd
# much much more ...

# to be run on plain jessie-lite
echo "Setting up TX-PI on jessie lite ..."

GITBASE="https://raw.githubusercontent.com/ftCommunity/ftcommunity-TXT/master/"
GITROOT=$GITBASE"board/fischertechnik/TXT/rootfs"
SVNBASE="https://github.com/ftCommunity/ftcommunity-TXT.git/trunk/"
SVNROOT=$SVNBASE"board/fischertechnik/TXT/rootfs"
TSVNBASE="https://github.com/harbaum/TouchUI.git/trunk/"
LOCALGIT="https://github.com/harbaum/tx-pi/raw/master/setup"

FTDDIRECT="ftduino_direct-1.0.5"

# Things you may do:
# set a root password
# enable root ssh login
# apt-get install emacs-nox

if [ "$HOSTNAME" != tx-pi ]; then
    echo "Make sure your R-Pi has been setup completely and is named tx-pi"
    exit -1
fi

# ----------------------- package installation ---------------------

apt-get update

# X11
apt-get -y install --no-install-recommends xserver-xorg xinit xserver-xorg-video-fbdev xserver-xorg-legacy unclutter
# python and pyqt
apt-get -y install --no-install-recommends python3-pyqt4 python3 python3-pip python3-numpy python3-dev cmake python3-serial python3-pexpect
# misc tools
apt-get -y install i2c-tools python3-smbus lighttpd git subversion ntpdate usbmount

# some additionl python stuff
pip3 install semantic_version
pip3 install websockets
sudo pip3 install --upgrade pyserial

# ---------------------- display setup ----------------------
# check if waveshare driver is installed
if [ ! -f /boot/overlays/waveshare32b-overlay.dtb ]; then
    echo "============================================================"
    echo "============== SCREEN DRIVER INSTALLATION =================="
    echo "============================================================"
    echo "= YOU NEED TO RESTART THIS SCRIPT ONCE THE PI HAS REBOOTED ="
    echo "============================================================"
    cd
    wget -N http://www.waveshare.com/w/upload/0/00/LCD-show-170703.tar.gz
    tar xvfz LCD-show-170703.tar.gz
    cd LCD-show
    ./LCD32-show
    # the pi will reboot
fi

# usbmount config
cd /etc/usbmount
wget -N https://raw.githubusercontent.com/ftCommunity/ftcommunity-TXT/3de48278d1260c48a0a20b07a35d14572c6248d3/board/fischertechnik/TXT/rootfs/etc/usbmount/usbmount.conf

# create file indicating that this is a tx-pi setup
touch /etc/tx-pi

# create locales
cat <<EOF > /etc/locale.gen
# locales supported by CFW 
en_US.UTF-8 UTF-8
de_DE.UTF-8 UTF-8
nl_NL.UTF-8 UTF-8
fr_FR.UTF-8 UTF-8
EOF
locale-gen
update-locale --no-checks LANG="de_DE.UTF-8"

# install bluetooth tools required for e.g. bnep
apt-get -y install --no-install-recommends bluez-tools

# fetch bluez hcitool with extended lescan patch
wget -N $LOCALGIT/hcitool-xlescan.tgz
tar xvfz hcitool-xlescan.tgz -C /usr/bin
rm -f hcitool-xlescan.tgz

# fetch precompiled opencv and its dependencies
# we might build our own package to get rid of these dependencies,
# especially gtk
apt-get -y install libjasper1 libgtk2.0-0 libavcodec56 libavformat56 libswscale3
wget -N https://github.com/jabelone/OpenCV-for-Pi/raw/master/latest-OpenCV.deb
dpkg -i latest-OpenCV.deb
rm -f latest-OpenCV.deb

apt-get -y install --no-install-recommends libzbar0 python3-pil 
apt-get -y install --no-install-recommends libzbar-dev
pip3 install zbarlight

# ----------------------- user setup ---------------------
# create ftc user
groupadd ftc
useradd -g ftc -m ftc
usermod -a -G video ftc
usermod -a -G tty ftc
usermod -a -G dialout ftc
usermod -a -G input ftc
usermod -a -G gpio ftc
usermod -a -G i2c ftc
echo "ftc:ftc" | chpasswd

# special ftc permissions
cd /etc/sudoers.d
wget -N $GITROOT/etc/sudoers.d/shutdown
chmod 0440 /etc/sudoers.d/shutdown
cat <<EOF > /etc/sudoers.d/bluetooth
## Permissions for ftc access to programs required
## for bluetooth setup

ftc     ALL = NOPASSWD: /usr/bin/hcitool, /etc/init.d/bluetooth, /usr/bin/pkill -SIGINT hcitool
EOF
chmod 0440 /etc/sudoers.d/bluetooth
cat <<EOF > /etc/sudoers.d/wifi
## Permissions for ftc access to programs required
## for wifi setup
ftc     ALL = NOPASSWD: /sbin/wpa_cli
EOF
chmod 0440 /etc/sudoers.d/wifi

cat <<EOF > /etc/sudoers.d/network
## Permissions for ftc access to programs required
## for network setup
ftc     ALL = NOPASSWD: /usr/bin/netreq, /etc/init.d/networking, /sbin/ifup, /sbin/ifdown
EOF
chmod 0440 /etc/sudoers.d/network

cat <<EOF > /etc/sudoers.d/ft_bt_remote_server
## Permissions for ftc access to programs required
## for BT Control Set server setup
ftc     ALL = NOPASSWD: /usr/bin/ft_bt_remote_start.sh, /usr/bin/ft_bt_remote_server, /usr/bin/pkill -SIGINT ft_bt_remote_server
EOF
chmod 0440 /etc/sudoers.d/ft_bt_remote_server

# ----------------------- display setup ---------------------

# disable fbturbo/enable ordinary fbdev
rm -f /usr/share/X11/xorg.conf.d/99-fbturbo.conf
cat <<EOF > /usr/share/X11/xorg.conf.d/99-fbdev.conf
Section "Device"
        Identifier      "FBDEV"
        Driver          "fbdev"
        Option          "fbdev" "/dev/fb1"

        Option          "SwapbuffersWait" "true"
EndSection
EOF

# X server/launcher start
cat <<EOF > /etc/systemd/system/launcher.service
[Unit]
Description=Start Launcher

[Service]
ExecStart=/bin/su ftc -c "PYTHONPATH=/opt/ftc startx /opt/ftc/launcher.py"
ExecStop=/usr/bin/killall xinit

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable launcher

# allow any user to start xs
sed -i 's,^\(allowed_users=\).*,\1'\anybody',' /etc/X11/Xwrapper.config

# rotate display
sed -i 's,^\(dtoverlay=waveshare32b.rotate=\).*,\1'\0',' /boot/config.txt

# rotate touchscreen 
cat <<EOF > /usr/share/X11/xorg.conf.d/99-calibration.conf
Section "InputClass"
Identifier "calibration"
MatchProduct "ADS7846 Touchscreen"
Option "Calibration" "200 3900 200 3900"
Option "SwapAxes" "0"
EndSection
EOF

# install framebuffer copy tool
wget -N $LOCALGIT/fbc.tgz
tar xvfz fbc.tgz
cd fbc
make
cp fbc /usr/bin/
cd ..
rm -rf fbc.tgz fbc

# install vnc server
apt-get -y install x11vnc

# hide cursor and disable screensaver
cat <<EOF > /etc/X11/xinit/xserverrc
#!/bin/sh
for f in /dev/input/by-id/*-mouse; do

    ## Check if the glob gets expanded to existing files.
    ## If not, f here will be exactly the pattern above
    ## and the exists test will evaluate to false.
    if [ -e "\$f" ]; then
        CUROPT=
        # run framebuffer copy tool in background
        /usr/bin/fbc &
        sh -c 'sleep 2; unclutter -display :0 -idle 1 -root' &
    else
        CUROPT=-nocursor
    fi

    ## This is all we needed to know, so we can break after the first iteration
    break
done

sh -c 'sleep 2; x11vnc -display :0 -forever' &

exec /usr/bin/X -s 0 dpms \$CUROPT -nolisten tcp "\$@"
EOF

# allow user to modify locale and network settings
touch /etc/locale
chmod 666 /etc/locale
cat <<EOF > /etc/network/interfaces
# /etc/network/interfaces
# generated by network.py

auto lo
auto wlan0
auto eth0

iface eth0 inet dhcp
iface wlan0 inet dhcp
        wpa-conf /etc/wpa_supplicant/wpa_supplicant.conf
iface lo inet loopback
EOF
chmod 666 /etc/network/interfaces

# set timezone to germany
echo "Europe/Berlin" > /etc/timezone

# set firmware version
cd /etc
wget -N $GITROOT/etc/fw-ver.txt

# set various udev rules to give ftc user access to
# hardware
cd /etc/udev/rules.d
wget -N $GITROOT/etc/udev/rules.d/40-fischertechnik_interfaces.rules
wget -N $GITROOT/etc/udev/rules.d/40-lego_interfaces.rules
wget -N $GITROOT/etc/udev/rules.d/60-i2c-tools.rules

# get /opt/ftc
echo "Populating /opt/ftc ..."
cd /opt
rm -rf ftc
svn export $SVNROOT"/opt/ftc"
cd /opt/ftc
# just fetch a copy of ftrobopy to make some programs happy
wget -N https://raw.githubusercontent.com/ftrobopy/ftrobopy/master/ftrobopy.py

# adjust font sizes/styles from qtembedded to x11
STYLE=/opt/ftc/themes/default/style.qss
# remove all "bold"
sed -i 's/^\(\s*font:\)\s*bold/\1/' $STYLE
# and scale some fonts
for i in 24:23 28:24 32:24; do
    from=`echo $i | cut -d':' -f1`
    to=`echo $i | cut -d':' -f2`
    sed -i "s/^\(\s*font:\)\s*${from}px/\1 ${to}px/" $STYLE
done

# install libroboint
echo "Installing libroboint"
wget -N $LOCALGIT/libroboint-inst.sh
chmod a+x libroboint-inst.sh
./libroboint-inst.sh
rm -f libroboint-inst.sh

# and ftduino_direct
echo "Installing ftduino_direct.py"
wget -N https://github.com/PeterDHabermehl/ftduino_direct/raw/master/$FTDDIRECT.tar.gz
tar -xzvf $FTDDIRECT.tar.gz 
cd $FTDDIRECT
sudo python3 ./setup.py install
cd ..
sudo rm -fr $FTDDIRECT $FTDDIRECT.tar.gz


# remove useless ftgui
rm -rf /opt/ftc/apps/system/ftgui

# add power tool from touchui
cd /opt/ftc/apps/system
svn export $TSVNBASE"/touchui/apps/system/power"

# add robolt support
# robolt udev rules have already been installed from the main repository
cd /root
git clone https://github.com/ftCommunity/python-robolt.git
cd python-robolt
python3 ./setup.py install
cd ..
rm -rf python-robolt

# add wedo support
# wedo udev rules have already been installed from the main repository
cd /root
git clone https://github.com/gbin/WeDoMore.git
cd WeDoMore
python3 ./setup.py install
rm -rf WeDoMore

# install the BT Control Set server
apt-get -y install --no-install-recommends libbluetooth-dev
cd /root
git clone https://github.com/ftCommunity/ft_bt_remote_server.git
cd ft_bt_remote_server
make
make install
cd ..
rm -rf ft_bt_remote_server

# install netreq
apt-get -y install --no-install-recommends libnetfilter-queue-dev
cd /root
svn export $SVNBASE"/package/netreq"
cd netreq
make
make install
cd ..
rm -rf netreq

cat <<EOF > /etc/netreq_permissions
# netreq permissions
EOF
chmod og+rw /etc/netreq_permissions

cat <<EOF > /etc/systemd/system/netreq.service
[Unit]
Description=Network requester

[Service]
Type=oneshot
ExecStart=/usr/bin/netreq_setup.sh

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable netreq


# build and install i2c-tiny-usb kernel module
apt-get install raspberrypi-kernel-headers
wget -N https://raw.githubusercontent.com/notro/rpi-source/master/rpi-source -O /usr/bin/rpi-source
chmod +x /usr/bin/rpi-source
/usr/bin/rpi-source -q --tag-update
apt-get install bc
rpi-source

mkdir i2c-tiny-usb
cd i2c-tiny-usb
echo -e "obj-m += i2c-tiny-usb.o" > Makefile
echo -e "\nall:" >> Makefile
echo -e "\tmake -C /lib/modules/\$(shell uname -r)/build M=\$(PWD) modules" >> Makefile
echo -e "\ninstall:" >> Makefile
echo -e "\tmake -C /lib/modules/\$(shell uname -r)/build M=\$(PWD) modules_install" >> Makefile
echo -e "\nclean:" >> Makefile
echo -e "\tmake -C /lib/modules/\$(shell uname -r)/build M=\$(PWD) clean" >> Makefile
cp ~/linux/drivers/i2c/busses/i2c-tiny-usb.c .
make
make install
depmod -a

# adjust lighttpd config
cat <<EOF > /etc/lighttpd/lighttpd.conf
server.modules = (
        "mod_access",
        "mod_alias",
        "mod_redirect"
)

server.document-root        = "/var/www"
server.upload-dirs          = ( "/var/cache/lighttpd/uploads" )
server.errorlog             = "/var/log/lighttpd/error.log"
server.pid-file             = "/var/run/lighttpd.pid"
server.username             = "ftc"
server.groupname            = "ftc"
server.port                 = 80


index-file.names            = ( "index.php", "index.html", "index.lighttpd.html" )
url.access-deny             = ( "~", ".inc" )
static-file.exclude-extensions = ( ".php", ".pl", ".fcgi" )

compress.cache-dir          = "/var/cache/lighttpd/compress/"
compress.filetype           = ( "application/javascript", "text/css", "text/html", "text/plain" )

# default listening port for IPv6 falls back to the IPv4 port

include_shell "/usr/share/lighttpd/use-ipv6.pl " + server.port
include_shell "/usr/share/lighttpd/create-mime.assign.pl"
include_shell "/usr/share/lighttpd/include-conf-enabled.pl"

server.modules += ( "mod_ssi" )
ssi.extension = ( ".html" )

server.modules += ( "mod_cgi" )

\$HTTP["url"] =~ "^/cgi-bin/" {
       cgi.assign = ( "" => "" )
}

cgi.assign      = (
       ".py"  => "/usr/bin/python3"
)
EOF

# fetch www pages
echo "Populating /var/www ..."
cd /var
rm -rf www
svn export $SVNROOT"/var/www"
touch /var/www/tx-pi

# convert most "fischertechnik TXT" texts to "ftcommunity TX-PI"
cd /var/www
for i in /var/www/*.html /var/www/*.py; do 
    sed -i 's.<div class="outline"><font color="red">fischer</font><font color="#046ab4">technik</font>\&nbsp;<font color="#fcce04">TXT</font></div>.<div class="outline"><font color="red">ft</font><font color="#046ab4">community</font>\&nbsp;<font color="#fcce04">TX-PI</font></div>.' $i
    sed -i 's.<title>fischertechnik TXT community firmware</title>.<title>ftcommunity TX-PI</title>.' $i
done

# add novnc link to index page
sed -i 's#<center><a href="https://github.com/ftCommunity/ftcommunity-TXT" target="ft-community">community edition</a></center>#<center><a href="https://github.com/ftCommunity/ftcommunity-TXT" target="ft-community">ftcommunity</a> - <a href="/remote">VNC</a></center>#' /var/www/index.html

# Install novnc ...
cd /var/www
wget -N $LOCALGIT/novnc.tgz
tar xvfz novnc.tgz
rm novnc.tgz

# ... and websockify for novnc
cd /opt/ftc
wget -N $LOCALGIT/websockify.tgz
tar xvfz websockify.tgz
rm websockify.tgz

# make sure fbgrab is there to take screenshots
apt-get -y install --no-install-recommends fbgrab
sed -i 's.fbgrab.fbgrab -d /dev/fb1.' /var/www/screenshot.py

# fbgrab needs netpbm to generate png files
apt-get -y install netpbm

# adjust file ownership for changed www user name
chown -R ftc:ftc /var/www/*
chown -R ftc:ftc /var/log/lighttpd
chown -R ftc:ftc /var/run/lighttpd
chown -R ftc:ftc /var/cache/lighttpd

mkdir /home/ftc/apps
chown -R ftc:ftc /home/ftc/apps

# disable the TXTs default touchscreen timeout as the waveshare isn't half
# as bad as the TXTs one
cat <<EOF > /home/ftc/.launcher.config 
[view]
min_click_time = 0
EOF
chown ftc:ftc /home/ftc/.launcher.config 

# remove cfw display configuration app since it does not work here...
rm -fr /opt/ftc/apps/system/display/
# 

/etc/init.d/lighttpd restart

echo "rebooting ..."

sync
reboot
