#!/bin/bash

# preparaion
# copy 2017-03-02-raspbian-jessie-lite.img to sd card
# set interfaces for eth0
# touch /boot/ssh
# -> boot pi
# raspi-config
#    hostname tx-pi (not mandatory, choose the name as you like)
#    enable ssh
#    optional disable wait for network

# TODO
# - add screen calibration tool
# - adjust timezone
# - fix wlan/eth
#   - don't wait for eth0
#   - control regular dhcpcd
# much much more ...

DEBUG=false
ENABLE_SPLASH=true
ENABLE_NETREQ=true

#-- Handle Jessie (8.x) vs. Stretch (9.x)
DEBIAN_VERSION=$( cat /etc/debian_version )
IS_STRETCH=false
if [ "${DEBIAN_VERSION:0:1}" = "9" ]; then
    IS_STRETCH=true
fi

if [ "$IS_STRETCH" = true ]; then
    echo "Setting up TX-PI on Stretch lite (EXPERIMENTAL!)"
else
    echo "Setting up TX-PI on Jessie lite"
fi

GITBASE="https://raw.githubusercontent.com/ftCommunity/ftcommunity-TXT/master/"
GITROOT=$GITBASE"board/fischertechnik/TXT/rootfs"
SVNBASE="https://github.com/ftCommunity/ftcommunity-TXT.git/trunk/"
SVNROOT=$SVNBASE"board/fischertechnik/TXT/rootfs"
TSVNBASE="https://github.com/harbaum/TouchUI.git/trunk/"
LOCALGIT="https://github.com/harbaum/tx-pi/raw/master/setup"

LIB_ROBOINT_URL=https://github.com/nxdefiant/libroboint/archive/
LIB_ROBOINT_FILE=0.5.3.zip
LIB_ROBOINT_IDIR=libroboint-0.5.3

FTDDIRECT="ftduino_direct-1.0.8"

# default lcd is 3.2 inch
LCD=LCD32
ORIENTATION=90

# check if user gave a parameter
if [ "$#" -gt 0 ]; then
    # todo: Allow for other types as well
    if [ "$1" == "LCD35" ]; then
        echo "Setup for waveshare 3.5 inch (A) screen"
        LCD=$1
    elif [ "$1" == "LCD35B" ]; then
        echo "Setup for waveshare 3.5 inch (B) IPS screen"
        LCD=$1
    else
        echo "Unknown parameter \"$1\""
        echo "Allowed parameters:"
        echo "LCD35    - create 3.5\" setup (instead of 3.2\")"
        echo "LCD35B   - create 3.5\" IPS setup)"
        exit -1
    fi
fi

# if [ "$HOSTNAME" != tx-pi ]; then
#     echo "Make sure your R-Pi has been setup completely and is named tx-pi"
#     exit -1
# fi

# ----------------------- package installation ---------------------

echo "Update Debian"
apt-get update
apt-get -y upgrade

# X11
apt-get -y install --no-install-recommends xserver-xorg xinit xserver-xorg-video-fbdev xserver-xorg-legacy unclutter
# python and pyqt
apt-get -y install --no-install-recommends python3 python3-pyqt4 python3-pip python3-numpy python3-dev cmake python3-pexpect
# python RPi GPIO access
apt-get -y install -y python3-rpi.gpio
apt-get -y install -y python-rpi.gpio
# misc tools
apt-get -y install i2c-tools python3-smbus lighttpd git subversion ntpdate usbmount
# avrdude
apt-get -y install avrdude
# Install Beautiful Soup 4.x
apt-get install -y python3-bs4

# some additional python stuff
pip3 install semantic_version
pip3 install websockets
pip3 install --upgrade setuptools


# DHCP client
if [ "$IS_STRETCH" = true ]; then
    # Remove dhcpcd because it fails to start (isc-dhcp-client is available)
    apt-get -y purge dhcpcd5
else
    # force "don't wait for network"
    rm -f /etc/systemd/system/dhcpcd.service.d/wait.conf
fi


# ---------------------- display setup ----------------------
echo "============================================================"
echo "============== SCREEN DRIVER INSTALLATION =================="
echo "============================================================"
cd
wget -N http://www.waveshare.com/w/upload/0/00/LCD-show-170703.tar.gz
tar xvfz LCD-show-170703.tar.gz
# supress automatic reboot after installation
sed -i "s/sudo reboot/#sudo reboot/g" LCD-show/$LCD-show
sed -i "s/\"reboot now\"/\"not rebooting yet\"/g" LCD-show/$LCD-show
cd LCD-show
./$LCD-show $ORIENTATION
# Clean up
rm -f LCD-show-170703.tar.gz
if [ "$DEBUG" = false ]; then
    rm -rf LCD-show
fi


# TODO:
# in /boot/config.txt for at least LCD35 and LCD35B set spi speed to 40Mhz like so:
# dtoverlay=waveshare35a:rotate=180 ->
# dtoverlay=waveshare35a:rotate=180,speed=40000000

# TODO1:
# adjust screen rotation

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

#TODO: May fail if /etc/ssh/ssh_config contains "SendEnv LANG LC_*" (default) and the TX-PI setup is run headless via SSH
update-locale --no-checks LANG="de_DE.UTF-8"

# install bluetooth tools required for e.g. bnep
apt-get -y install --no-install-recommends bluez-tools

# fetch bluez hcitool with extended lescan patch
wget -N $LOCALGIT/hcitool-xlescan.tgz
tar xvfz hcitool-xlescan.tgz -C /usr/bin
rm -f hcitool-xlescan.tgz

# Install OpenCV
if [ "$IS_STRETCH" = true ]; then
   apt-get -y install --no-install-recommends libatlas3-base libwebp6 libtiff5 libjasper1 libilmbase12 \
                                              libopenexr22 libilmbase12 libgstreamer1.0-0 \
                                              libavcodec57 libavformat57 libavutil55 libswscale4 \
                                              libgtk-3-0 libpangocairo-1.0-0 libpango-1.0-0 libatk1.0-0 \
                                              libcairo-gobject2 libcairo2 libgdk-pixbuf2.0-0
   pip3 install opencv-python-headless
else
    # fetch precompiled opencv and its dependencies
    # we might build our own package to get rid of these dependencies,
    # especially gtk
    apt-get -y install libjasper1 libgtk2.0-0 libavcodec56 libavformat56 libswscale3
    wget -N https://github.com/jabelone/OpenCV-for-Pi/raw/master/latest-OpenCV.deb
    dpkg -i latest-OpenCV.deb
    rm -f latest-OpenCV.deb
fi

apt-get -y install --no-install-recommends libzbar0 python3-pil 
apt-get -y install --no-install-recommends libzbar-dev
pip3 install zbarlight

# system wide mpg123 overrides the included mpg123 of some apps
apt-get -y install --no-install-recommends mpg123

# ----------------------- user setup ---------------------
# create ftc user
groupadd ftc
useradd -g ftc -m ftc
usermod -a -G video ftc
usermod -a -G audio ftc
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

# Splash screen
if [ "$ENABLE_SPLASH" = true ]; then
    # a simple boot splash
    wget -N $LOCALGIT/splash.png -O /etc/splash.png
    apt-get install -y --no-install-recommends libjpeg-dev
    cd
    wget -N https://github.com/godspeed1989/fbv/archive/master.zip
    unzip -x master.zip
    cd fbv-master/
    FRAMEBUFFER=/dev/fb1 ./configure
    make
    make install
    cd ..
    rm -rf master.zip fbv-master
    if [ "$IS_STRETCH" = true ]; then
        # Remove plymouth otherwise the splash is not shown
        #TODO: CAUTION: Removes "mountall" due to a strange dependency, too.
        # Another solution: Install or create a plymouth theme.
        # IMO too much work for a simple, almost useless splash screen
        # BTW: "systemctl mask plymouth" does not work
        apt-get -y purge plymouth
        ENABLE_DEFAULT_DEPENDENCIS="yes"
        cmd_line=$( cat /boot/cmdline.txt )
        # These params are needed to show the splash screen
        # Append them to the cmdline.txt without changing other params
        for param in "logo.nologo" "vt.global_cursor_default=0" "quiet"
        do
            if [[ $cmd_line != *"$param"* ]]; then
                cmd_line="$cmd_line $param"
            fi
        done
        cat <<EOF > /boot/cmdline.txt
${cmd_line}
EOF
    else
        ENABLE_DEFAULT_DEPENDENCIS="no"
        # disable any text output on the LCD
        cat <<EOF > /boot/cmdline.txt
dwc_otg.lpm_enable=0 console=ttyAMA0,115200 root=/dev/mmcblk0p2 rootfstype=ext4 elevator=deadline rootwait logo.nologo quiet
EOF
    fi
    # create a service to start fbv at startup
    cat <<EOF > /etc/systemd/system/splash.service
[Unit]
DefaultDependencies=${ENABLE_DEFAULT_DEPENDENCIS}
After=local-fs.target

[Service]
StandardInput=tty
StandardOutput=tty
ExecStart=/bin/sh -c "echo 'q' | fbv -e /etc/splash.png"

[Install]
WantedBy=sysinit.target
EOF
    systemctl daemon-reload
    systemctl disable getty@tty1
    systemctl enable splash
fi  # End ENABLE_SPLASH

# allow any user to start xs
sed -i 's,^\(allowed_users=\).*,\1'\anybody',' /etc/X11/Xwrapper.config

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
wget -N $GITROOT/etc/udev/rules.d/99-USBasp.rules

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
# install libusb-dev
apt-get install libusb-dev
wget -N $LIB_ROBOINT_URL$LIB_ROBOINT_FILE
unzip $LIB_ROBOINT_FILE
# build
cd $LIB_ROBOINT_IDIR
cmake .
make
#TODO: Fails. Remove?
if [ true = false ]; then
    make doc
fi
# install
make install
ldconfig
# install python
make python
# udev rules
cp udev/fischertechnik.rules /etc/udev/rules.d/
# python3 compatibility 'patch'
cd ..
wget -N https://github.com/PeterDHabermehl/libroboint-py3/raw/master/robointerface.py
cp robointerface.py /usr/local/lib/python3.5/dist-packages/
if [ "$IS_STRETCH" = false ]; then
    cp robointerface.py /usr/local/lib/python3.4/dist-packages/
fi
# clean up
rm -f robointerface.py
rm -f $LIB_ROBOINT_FILE
rm -rf $LIB_ROBOINT_IDIR


# and ftduino_direct
echo "Installing ftduino_direct.py"
wget -N https://github.com/PeterDHabermehl/ftduino_direct/raw/master/$FTDDIRECT.tar.gz
tar -xzvf $FTDDIRECT.tar.gz 
cd $FTDDIRECT
python3 ./setup.py install
cd ..
rm -f $FTDDIRECT.tar.gz
rm -rf $FTDDIRECT
rm -f /opt/ftc/ftduino_direct.py

# remove useless ftgui
rm -rf /opt/ftc/apps/system/ftgui

# add power tool from touchui
cd /opt/ftc/apps/system
svn export $TSVNBASE"/touchui/apps/system/power"

# add screen calibration tool
apt-get -y install --no-install-recommends xinput-calibrator
chmod og+rw /usr/share/X11/xorg.conf.d/99-calibration.conf
cd /opt/ftc/apps/system
mkdir tscal
cd tscal
wget -N $LOCALGIT/tscal.zip
unzip -o tscal.zip
rm tscal.zip

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
cd ..
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

if [ "$ENABLE_NETREQ" = true ]; then
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
Wants=network-online.target
After=network-online.target

[Service]
Type=oneshot
ExecStart=/usr/bin/netreq

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    systemctl enable netreq
fi

# build and install i2c-tiny-usb kernel module
# This doesn't work at this stage since the newly istalled
# kernel isn't running yet
#apt-get -y install raspberrypi-kernel-headers
#wget -N https://raw.githubusercontent.com/notro/rpi-source/master/rpi-source -O /usr/bin/rpi-source
#chmod +x /usr/bin/rpi-source
#/usr/bin/rpi-source -q --tag-update
#apt-get -y install bc
#rpi-source

#mkdir i2c-tiny-usb
#cd i2c-tiny-usb
#echo -e "obj-m += i2c-tiny-usb.o" > Makefile
#echo -e "\nall:" >> Makefile
#echo -e "\tmake -C /lib/modules/\$(shell uname -r)/build M=\$(PWD) modules" >> Makefile
#echo -e "\ninstall:" >> Makefile
#echo -e "\tmake -C /lib/modules/\$(shell uname -r)/build M=\$(PWD) modules_install" >> Makefile
#echo -e "\nclean:" >> Makefile
#echo -e "\tmake -C /lib/modules/\$(shell uname -r)/build M=\$(PWD) clean" >> Makefile
#cp ~/linux/drivers/i2c/busses/i2c-tiny-usb.c .
#make
#make install
#depmod -a


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
chown -R ftc:ftc /var/www

# fbgrab needs netpbm to generate png files
apt-get -y install netpbm

if [ "$IS_STRETCH" = true ]; then
    apt-get -y install --no-install-recommends fbcat
else
    apt-get -y install --no-install-recommends fbgrab
fi
sed -i 's.fbgrab.fbgrab -d /dev/fb1.' /var/www/screenshot.py


# adjust file ownership for changed www user name
chown -R ftc:ftc /var/www
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
sleep 30
shutdown -r now
