#!/bin/bash
#===============================================================================
# TX-Pi setup script.
#
# See <https://www.tx-pi.de/en/installation/> or
# <https://www.tx-pi.de/de/installation/> (German) for detailed installation
# instructions.
#
# In short:
# * Copy a supported Raspbian lite version onto SD card
# * Either plug-in your display and a keyboard or enable SSH and add your
#   WLAN configuration via /boot/ssh and /boot/wpa_supplicant.conf, see
#   <https://www.raspberrypi.org/documentation/configuration/wireless/headless.md>
#   for details
# * Insert the SD card into your Pi and boot it
# * Log into your Pi and download the script via
#   wget https://tx-pi.de/tx-pi-setup.sh
# * Run the script
#   sudo bash ./tx-pi-setup.sh
#   You can also specify your touch screen device, i.e.
#   sudo bash ./tx-pi-setup.sh LCD35
#   to support the popular Waveshare LCD 3.5" type "A" display.
#   See <https://www.tx-pi.de/en/installation/> for details
# * After running the script, the Pi will boot into the fischertechnik community
#   firmware.
#===============================================================================

# Schema: YY.<release-number-within-the-year>.minor(.dev)?
TX_PI_VERSION='20.1.0.dev'

DEBUG=false
ENABLE_SPLASH=true
ENABLE_NETREQ=false

function msg {
    echo -e "\033[93m$1\033[0m"
}

function header {
    echo -e "\033[0;32m--- $1 ---\033[0m"
}


function error {
    echo -e "\033[0;31m$1\033[0m"
}

#-- Handle Stretch (9.x) vs. Buster (10.x)
DEBIAN_VERSION=$( cat /etc/debian_version )
IS_STRETCH=false
IS_BUSTER=true

if [ "${DEBIAN_VERSION:0:1}" = "9" ]; then
    IS_STRETCH=true
    ENABLE_NETREQ=true
elif [ "${DEBIAN_VERSION:0:2}" = "10" ]; then
    IS_BUSTER=true
elif [ "${DEBIAN_VERSION:0:1}" = "8" ]; then
    error "Debian Jessie is not supported anymore"
    exit 2
else
    error "Unknown Raspbian version: '${DEBIAN_VERSION}'"
    exit 2
fi

if [ "$IS_STRETCH" = true ]; then
    header "Setting up TX-Pi on Stretch lite"
elif [ "$IS_BUSTER" = true ]; then
    header "Setting up TX-Pi on Buster lite"
fi

GITBASE="https://raw.githubusercontent.com/ftCommunity/ftcommunity-TXT/master/"
GITROOT=$GITBASE"board/fischertechnik/TXT/rootf2s"
SVNBASE="https://github.com/ftCommunity/ftcommunity-TXT.git/trunk/"
SVNROOT=$SVNBASE"board/fischertechnik/TXT/rootfs"
TSVNBASE="https://github.com/harbaum/TouchUI.git/trunk/"
LOCALGIT="https://github.com/ftCommunity/tx-pi/raw/master/setup"

FTDDIRECT="ftduino_direct-1.0.8"

# TX-Pi app store
TXPIAPPS_URL="https://github.com/ftCommunity/tx-pi-apps/raw/master/packages/"

# TX-Pi config
TXPICONFIG_SCRIPTS_DIR="/opt/ftc/apps/system/txpiconfig/scripts"


# default lcd is 3.2 inch
LCD=LCD32
ORIENTATION=90
# check if user gave a parameter
if [ "$#" -gt 0 ]; then
    # todo: Allow for other types as well
    LCD=$1
    if [ "$1" == "LCD35" ]; then
        header "Setup for Waveshare 3.5 inch (A) screen"
    elif [ "$1" == "LCD35B" ]; then
        header "Setup for Waveshare 3.5 inch (B) IPS screen"
    elif [ "$1" == "LCD35BV2" ]; then
        header "Setup for Waveshare 3.5 inch (B) IPS rev. 2 screen"
    else
        error "Unknown parameter \"$1\""
        error "Allowed parameters:"
        error "LCD35    - create 3.5\" setup (instead of 3.2\")"
        error "LCD35B   - create 3.5\" IPS setup"
        error "LCD35BV2 - create 3.5\" IPS rev. 2 setup"
        exit 2
    fi
fi

# ----------------------- package installation ---------------------

header "Update Debian"
apt-get update
apt --fix-broken -y install
apt-get -y upgrade

# X11
apt-get -y install --no-install-recommends xserver-xorg xinit xserver-xorg-video-fbdev xserver-xorg-legacy unclutter
# python and pyqt
apt-get -y install --no-install-recommends python3 python3-pyqt4 python3-pip python3-numpy python3-dev cmake python3-pexpect
# python RPi GPIO access
apt-get -y install -y python3-rpi.gpio
apt-get -y install -y python-rpi.gpio  #TODO: Still necessary?
# misc tools
apt-get -y install i2c-tools python3-smbus lighttpd git subversion ntpdate usbmount
# avrdude
apt-get -y install avrdude
# Install Beautiful Soup 4.x
apt-get install -y python3-bs4

# some additional python stuff
header "Install Python libs"
if [ "$IS_STRETCH" = true ]; then
    pip3 install -U semantic_version websockets setuptools \
        wheel  # Needed for zbar
else
    apt-get -y install --no-install-recommends python3-semantic-version \
        python3-websockets python3-setuptools python3-wheel
fi


# DHCP client
header "Setup DHCP client"
# Remove dhcpcd because it fails to start (isc-dhcp-client is available)
apt-get -y purge dhcpcd5
# Do not try too long to reach the DHCPD server (blocks booting)
sed -i "s/#timeout 60;/timeout 10;/g" /etc/dhcp/dhclient.conf
# By default, the client retries to contact the DHCP server after five min.
# Reduce this time to 20 sec.
sed -i "s/#retry 60;/retry 20;/g" /etc/dhcp/dhclient.conf

# ---------------------- display setup ----------------------
header "Install screen driver"
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


#-- Support for the TX-Pi HAT
# Enable I2c
raspi-config nonint do_i2c 0 dtparam=i2c_arm=on
sed -i "s/dtparam=i2c_arm=on/dtparam=i2c_arm=on\ndtparam=i2c_vc=on/g" /boot/config.txt
# Disable RTC
sed -i "s/exit 0/\# ack pending RTC wakeup\n\/usr\/sbin\/i2cset -y 0 0x68 0x0f 0x00\n\nexit 0/g" /etc/rc.local
# Power control via GPIO4
echo "dtoverlay=gpio-poweroff,gpiopin=4,active_low=1" >> /boot/config.txt


#-- Enable WLAN iff it isn't enabled yet
if [ "$(wpa_cli -i wlan0 get country)" == "FAIL" ]; then
    msg "Enable WLAN"
    wpa_cli -i wlan0 set country DE
    wpa_cli -i wlan0 save_config
    rfkill unblock wifi
else
    msg "WLAN already configured, don't touch it"
fi


# usbmount config
cd /etc/usbmount
wget -N https://raw.githubusercontent.com/ftCommunity/ftcommunity-TXT/3de48278d1260c48a0a20b07a35d14572c6248d3/board/fischertechnik/TXT/rootfs/etc/usbmount/usbmount.conf

# create file indicating that this is a tx-pi setup
touch /etc/tx-pi

# TX-Pi version information
echo "${TX_PI_VERSION}" > /etc/tx-pi-ver.txt


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

apt-get -y install --no-install-recommends libzbar0 python3-pil libzbar-dev
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

cat <<EOF > /etc/sudoers.d/txpiconfig
## Permissions for ftc access to programs required
## for the TX-Pi config app and the app store (install dependencies via apt-get)
ftc     ALL = NOPASSWD: ${TXPICONFIG_SCRIPTS_DIR}/hostname, ${TXPICONFIG_SCRIPTS_DIR}/ssh, ${TXPICONFIG_SCRIPTS_DIR}/x11vnc, ${TXPICONFIG_SCRIPTS_DIR}/display, ${TXPICONFIG_SCRIPTS_DIR}/i2cbus, /usr/bin/apt-get
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
if [ "$IS_BUSTER" = true ]; then
    # VNC support in Buster is broken / may deliver distorted output
    # Remove libvncserver1 if any
    apt-get -y remove libvncserver1 x11vnc-data libvncclient1
    cat <<EOF > /etc/apt/preferences.d/buster.pref
# Added by TX-Pi setup to solve VNC problems with Buster.
Package: *
Pin: release a=buster
Pin-Priority: 900
EOF
    cat <<EOF > /etc/apt/preferences.d/jessie.pref
# Added by TX-Pi setup to solve VNC problems with Buster.
Package: *
Pin: release a=jessie
Pin-Priority: 50
EOF
    if [[ $( cat /etc/apt/sources.list ) != *"Jessie"* ]]; then
        echo "# Jessie repository added by TX-Pi setup to solve VNC problems" >> /etc/apt/sources.list
        echo "deb http://raspbian.raspberrypi.org/raspbian/ jessie main contrib non-free rpi" >> /etc/apt/sources.list
    fi
    apt-get update
    apt-get -y install -t=jessie x11vnc
else
    apt-get -y install x11vnc
fi
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
header "Populating /opt/ftc ..."
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
header "Installing libroboint"
rm -f /usr/local/lib/libroboint.so*
# install libusb-dev
apt-get install libusb-dev
git clone https://gitlab.com/Humpelstilzchen/libroboint.git
cd libroboint
# python3 compatibility 'patch'
sed -i "s/python2/python3/g" ./CMakeLists.txt
cmake .
make
# install
make install
ldconfig
# install python
make python
# udev rules
cp udev/fischertechnik.rules /etc/udev/rules.d/
cd ..
# clean up
rm -rf libroboint


# and ftduino_direct
header "Installing ftduino_direct.py"
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

# Remove old app
rm -rf /opt/ftc/apps/system/tscal

# Remove any installed TS-Cal
rm -rf /home/ftc/apps/ffe0d8c4-be33-4f62-b25d-2fa7923daaa2

cd /home/ftc/apps
wget "${TXPIAPPS_URL}tscal.zip"
unzip -o tscal.zip -d ffe0d8c4-be33-4f62-b25d-2fa7923daaa2
chown -R ftc:ftc ffe0d8c4-be33-4f62-b25d-2fa7923daaa2
chmod +x ffe0d8c4-be33-4f62-b25d-2fa7923daaa2/tscal.py
rm -f ./tscal.zip


#
# - Add TX-Pi config
#
TXPICONFIG_DIR="/home/ftc/apps/e7b22a70-7366-4090-b251-5fead780c5a0"
# Remove old app to configure SSH and VNC servers.
# Became obsolete due to new TX-Pi config
rm -rf /home/ftc/apps/430d692e-d285-4f05-82fd-a7b3ce9019e5
rm -rf /home/ftc/apps/e7b22a70-7366-4090-b251-5fead780c5a0
rm -f /etc/sudoers.d/sshvnc
rm -rf /opt/ftc/apps/system/txpiconfig

# Remove any installed TX-Pi config
rm -rf ${TXPICONFIG_DIR}

cd /home/ftc/apps
wget "${TXPIAPPS_URL}config.zip"
wget "${TXPIAPPS_URL}/config/scripts.zip"
mkdir -p "${TXPICONFIG_DIR}"
mkdir -p "${TXPICONFIG_SCRIPTS_DIR}"
unzip -o config.zip -d "${TXPICONFIG_DIR}"
unzip -o scripts.zip -d "${TXPICONFIG_SCRIPTS_DIR}"
chown -R ftc:ftc ${TXPICONFIG_DIR}
chmod +x ${TXPICONFIG_DIR}/config.py
chown root:root ${TXPICONFIG_SCRIPTS_DIR}/*
chmod 744 ${TXPICONFIG_SCRIPTS_DIR}/*
rm -f ./config.zip
rm -f ./scripts.zip


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
header "Populating /var/www ..."
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

# In Buster, systemd (tmpfiles.d) resets the permissions to www-data if the
# system reboots. This ensures that the permissions are kept alive.
if [ "$IS_STRETCH" = false ]; then
    sed -i "s/www-data/ftc/g" /usr/lib/tmpfiles.d/lighttpd.tmpfile.conf
fi


mkdir -p /home/ftc/apps
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


#-- Add useful TX-Pi stores
shop_repositories="/home/ftc/.repositories.xml"
if [ ! -f "$shop_repositories" ]; then
  cat <<EOF > $shop_repositories
<repositories>
  <repository name="TX-Pi Apps" repo="tx-pi-apps" user="ftCommunity"/>
  <repository name="Till&apos;s Apps" repo="cfw-apps" user="harbaum"/>
</repositories>
EOF
fi

msg "rebooting ..."

sync
sleep 30
shutdown -r now
