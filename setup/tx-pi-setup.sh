#!/bin/bash

# preparaion
# copy raspbian-lite.img to sd card
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
ENABLE_NETREQ=false

#-- Handle Stretch (9.x) vs. Buster (10.x)
DEBIAN_VERSION=$( cat /etc/debian_version )
IS_STRETCH=false
IS_BUSTER=true
PYTHON_VERSION='python3.7'  # Required for Robointerface, lower case major version

if [ "${DEBIAN_VERSION:0:1}" = "9" ]; then
    IS_STRETCH=true
    ENABLE_NETREQ=true
    PYTHON_VERSION='python3.5'
elif [ "${DEBIAN_VERSION:0:2}" = "10" ]; then
    IS_BUSTER=true
elif [ "${DEBIAN_VERSION:0:1}" = "8" ]; then
    echo "Debian Jessie is not supported anymore"
    exit 2
else
    echo "Unknown Debian version: '${DEBIAN_VERSION}'"
    exit 2
fi

if [ "$IS_STRETCH" = true ]; then
    echo "Setting up TX-Pi on Stretch lite"
elif [ "$IS_BUSTER" = true ]; then
    echo "Setting up TX-Pi on Buster lite"
fi

GITBASE="https://raw.githubusercontent.com/ftCommunity/ftcommunity-TXT/master/"
GITROOT=$GITBASE"board/fischertechnik/TXT/rootfs"
SVNBASE="https://github.com/ftCommunity/ftcommunity-TXT.git/trunk/"
SVNROOT=$SVNBASE"board/fischertechnik/TXT/rootfs"
TSVNBASE="https://github.com/harbaum/TouchUI.git/trunk/"
LOCALGIT="https://github.com/ftCommunity/tx-pi/raw/master/setup"

LIB_ROBOINT_URL=https://github.com/nxdefiant/libroboint/archive/
LIB_ROBOINT_FILE=0.5.3.zip
LIB_ROBOINT_IDIR=libroboint-0.5.3

FTDDIRECT="ftduino_direct-1.0.8"

# TX-Pi touchscreen calibration
TXPITSCAL_URL="https://github.com/ftCommunity/txpitscal/archive/master.zip"
TXPITSCAL_DIR="/opt/ftc/apps/system/tscal"

# TX-Pi config
TXPICONFIG_URL="https://github.com/ftCommunity/txpiconfig/archive/master.zip"
TXPICONFIG_DIR="/opt/ftc/apps/system/txpiconfig"

# default lcd is 3.2 inch
LCD=LCD32
ORIENTATION=90
# check if user gave a parameter
if [ "$#" -gt 0 ]; then
    # todo: Allow for other types as well
    LCD=$1
    if [ "$1" == "LCD35" ]; then
        echo "Setup for Waveshare 3.5 inch (A) screen"
    elif [ "$1" == "LCD35B" ]; then
        echo "Setup for Waveshare 3.5 inch (B) IPS screen"
    elif [ "$1" == "LCD35BV2" ]; then
        echo "Setup for Waveshare 3.5 inch (B) IPS rev. 2 screen"
    else
        echo "Unknown parameter \"$1\""
        echo "Allowed parameters:"
        echo "LCD35    - create 3.5\" setup (instead of 3.2\")"
        echo "LCD35B   - create 3.5\" IPS setup"
        echo "LCD35BV2 - create 3.5\" IPS rev. 2 setup"
        exit -1
    fi
fi

# ----------------------- package installation ---------------------

echo "Update Debian"
apt-get update
apt --fix-broken -y install
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
if [ "$IS_STRETCH" = true ]; then
    pip3 install semantic_version
    pip3 install websockets
    pip3 install --upgrade setuptools
    pip3 install --upgrade wheel  # Needed for zbar
else
    apt-get -y install python3-setuptools
    apt-get -y install python3-wheel
    apt-get -y install python3-semantic-version
    apt-get -y install python3-websockets
fi


# DHCP client
# Remove dhcpcd because it fails to start (isc-dhcp-client is available)
apt-get -y purge dhcpcd5
# Do not try too long to reach the DHCPD server (blocks booting)
sed -i "s/#timeout 60;/timeout 10;/g" /etc/dhcp/dhclient.conf
# By default, the client retries to contact the DHCP server after five min.
# Reduce this time to 20 sec.
sed -i "s/#retry 60;/retry 20;/g" /etc/dhcp/dhclient.conf

# ---------------------- display setup ----------------------
echo "============================================================"
echo "============== SCREEN DRIVER INSTALLATION =================="
echo "============================================================"
cd
wget -N https://www.waveshare.com/w/upload/0/00/LCD-show-170703.tar.gz
tar xvfz LCD-show-170703.tar.gz
if [ ${LCD} == "LCD35BV2" ]; then
    # Support for Waveshare 3.5" "B" rev. 2.0
    # This display is not supported by the LCD-show-170703 driver but by
    # the Waveshare GH repository.
    # We won't switch to the GH repository soon since it causes more problems
    # than blessing (2019-04)
    cp ./LCD-show/LCD35B-show ./LCD-show/$LCD-show
    wget https://github.com/waveshare/LCD-show/raw/master/waveshare35b-v2-overlay.dtb -P ./LCD-show/
    sed -i "s/waveshare35b/waveshare35b-v2/g" ./LCD-show/$LCD-show
fi
# supress automatic reboot after installation
sed -i "s/sudo reboot/#sudo reboot/g" LCD-show/$LCD-show
sed -i "s/\"reboot now\"/\"not rebooting yet\"/g" LCD-show/$LCD-show
cd LCD-show
./$LCD-show $ORIENTATION
# Clean up
cd ..
rm -f ./LCD-show-170703.tar.gz
if [ "$DEBUG" = false ]; then
    rm -rf ./LCD-show
fi
if [ $LCD == "LCD35BV2" ]; then
    # Support for Waveshare 3.5" "B" rev. 2.0
    sed -i "s/waveshare35b/waveshare35b-v2/g" /boot/config.txt
fi

# Driver installation changes "console=serial0,115200" to "console=ttyAMA0,115200"
# Revert it here since /dev/ttyAMA0 is Bluetooth (Pi3, Pi3B+ ...)
sed -i "s/=ttyAMA0,/=serial0,/g" /boot/cmdline.txt
cmd_line=$( cat /boot/cmdline.txt )
# Driver installation removes "fsck.repair=yes"; revert it
if [[ $cmd_line != *"fsck.repair=yes"* ]]; then
    cmd_line="$cmd_line fsck.repair=yes"
fi
cat <<EOF > /boot/cmdline.txt
${cmd_line}
EOF

# Screen driver installation enables I2C without actually loading the
# necessary modules. Revert it.
sed -i "s/^dtparam=i2c_arm=on/#dtparam=i2c_arm=on/g" /boot/config.txt


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

#TODO: May fail if /etc/ssh/ssh_config contains "SendEnv LANG LC_*" (default) and the TX-Pi setup is run headless via SSH
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
    apt-get -y install --no-install-recommends python3-opencv
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
usermod -a -G www-data ftc
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

cat <<EOF > /etc/sudoers.d/txpiconfig
## Permissions for ftc access to programs required
## for the TX-Pi config app
ftc     ALL = NOPASSWD: ${TXPICONFIG_DIR}/scripts/hostname, ${TXPICONFIG_DIR}/scripts/ssh, ${TXPICONFIG_DIR}/scripts/x11vnc, ${TXPICONFIG_DIR}/scripts/display, ${TXPICONFIG_DIR}/scripts/i2cbus
EOF
chmod 0440 /etc/sudoers.d/txpiconfig


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


# Configure X.Org to use /dev/fb1
x_fbdev_conf="/usr/share/X11/xorg.conf.d/99-fbdev.conf"
# Patch X.Org to use /dev/fb1
rm -f ${x_fbdev_conf}
cat <<EOF > ${x_fbdev_conf}
Section "Device"
    Identifier      "FBDEV"
    Driver          "fbdev"
    Option          "fbdev" "/dev/fb1"
    Option          "SwapbuffersWait" "true"
EndSection
EOF


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
    enable_default_dependencies="yes"
    cmd_line=$( cat /boot/cmdline.txt )
    # These params are needed to show the splash screen and to omit any text output on the LCD
    # Append them to the cmdline.txt without changing other params
    for param in "logo.nologo" "vt.global_cursor_default=0" "plymouth.ignore-serial-consoles" "splash" "quiet"
    do
        if [[ $cmd_line != *"$param"* ]]; then
            cmd_line="$cmd_line $param"
        fi
    done
    cat <<EOF > /boot/cmdline.txt
${cmd_line}
EOF
    # create a service to start fbv at startup
    cat <<EOF > /etc/systemd/system/splash.service
[Unit]
DefaultDependencies=${enable_default_dependencies}
After=local-fs.target

[Service]
StandardInput=tty
StandardOutput=tty
Type=oneshot
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

# Hide cursor and disable screensaver
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

exec /usr/bin/X -s 0 dpms \$CUROPT -nolisten tcp "\$@"
EOF


# Install vnc server
apt-get -y install x11vnc
cat <<EOF > /etc/systemd/system/x11vnc.service
[Unit]
Description=X11 VNC service
After=network.target

[Service]
ExecStart=/bin/su ftc -c "/usr/bin/x11vnc -forever"
ExecStop=/bin/su ftc -c "/usr/bin/killall x11vnc"

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable x11vnc


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

# set timezone to Germany
ln -fs /usr/share/zoneinfo/Europe/Berlin /etc/localtime
dpkg-reconfigure -f noninteractive tzdata

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
cp robointerface.py /usr/local/lib/${PYTHON_VERSION}/dist-packages/
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
# Move power button to home screen
sed -i "s/category: System/category: /g" /opt/ftc/apps/system/power/manifest


#
# - Add TX-Pi TS-Cal
#
apt-get -y install --no-install-recommends xinput-calibrator
chmod og+rw /usr/share/X11/xorg.conf.d/99-calibration.conf

# Remove any installed TS-Cal
rm -rf ${TXPITSCAL_DIR}

cd /root
wget ${TXPITSCAL_URL} -O txpitscal.zip
unzip -o txpitscal.zip
rm -f ./txpitscal.zip
mv ./txpitscal-* ./tscal  # Reliable diretory name
mv ./tscal ${TXPITSCAL_DIR}


#
# - Add TX-Pi config
#
# Remove old app to configure SSH and VNC servers.
# Became obsolete due to new TX-Pi config
rm -rf /home/ftc/apps/430d692e-d285-4f05-82fd-a7b3ce9019e5
rm -rf /home/ftc/apps/e7b22a70-7366-4090-b251-5fead780c5a0  # Previous location of TX-Pi conig
rm -f /etc/sudoers.d/sshvnc

# Remove any installed TX-Pi config
rm -rf ${TXPICONFIG_DIR}

cd /root
wget ${TXPICONFIG_URL} -O txpiconfig.zip
unzip -o txpiconfig.zip
rm -f ./txpiconfig.zip
mv ./txpiconfig-* ./txpiconfig  # Reliable diretory name
mv ./txpiconfig ${TXPICONFIG_DIR}
chown root:root ${TXPICONFIG_DIR}/scripts/*
chmod 744 ${TXPICONFIG_DIR}/scripts/*


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
Type=simple
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

lighttpd_mime_types="/usr/share/lighttpd/create-mime.conf.pl"
lighttpd_config="include \"/etc/lighttpd/conf-enabled/*.conf\""

if [ "$IS_STRETCH" = true ]; then
    lighttpd_mime_types="/usr/share/lighttpd/create-mime.assign.pl"
    lighttpd_config="include_shell \"/usr/share/lighttpd/include-conf-enabled.pl\""
fi

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

# default listening port for IPv6 falls back to the IPv4 port

include_shell "/usr/share/lighttpd/use-ipv6.pl " + server.port
include_shell "${lighttpd_mime_types}"
${lighttpd_config}

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

# convert most "fischertechnik TXT" texts to "ftcommunity TX-Pi"
cd /var/www
for i in /var/www/*.html /var/www/*.py; do 
    sed -i 's.<div class="outline"><font color="red">fischer</font><font color="#046ab4">technik</font>\&nbsp;<font color="#fcce04">TXT</font></div>.<div class="outline"><font color="red">ft</font><font color="#046ab4">community</font>\&nbsp;<font color="#fcce04">TX-Pi</font></div>.' $i
    sed -i 's.<title>fischertechnik TXT community firmware</title>.<title>ftcommunity TX-Pi</title>.' $i
done

# add VNC and TX-Pi homepage link to index page
sed -i 's#<center><a href="https://github.com/ftCommunity/ftcommunity-TXT" target="ft-community">community edition</a></center>#<center><a href="https://github.com/ftCommunity/ftcommunity-TXT" target="ft-community">ftcommunity</a> - <a href="https://www.tx-pi.de/" target="tx-pi">TX-Pi</a> - <a href="/remote">VNC</a></center>#' /var/www/index.html

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

apt-get -y install --no-install-recommends fbcat
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

echo "rebooting ..."

sync
sleep 30
shutdown -r now
