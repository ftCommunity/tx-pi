#!/bin/bash
#===============================================================================
# TX-Pi setup script.
#
# See <https://www.tx-pi.de/en/installation/> or
# <https://www.tx-pi.de/de/installation/> (German) for detailed installation
# instructions.
#
# In short:
# * Copy a supported Raspberry Pi OS Lite version onto SD card
# * Either plug-in your display and a keyboard or enable SSH.
#   Optionally, add your WLAN configuration via /boot/wpa_supplicant.conf, see
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
set -ue
# Schema: YY.<release-number-within-the-year>.minor(.dev)?
# See <https://calver.org/> for details
TX_PI_VERSION='25.1.0-dev'

DEBUG=true
ENABLE_SPLASH=false

function msg {
    echo -e "\033[93m$1\033[0m"
}

function header {
    echo -e "\033[0;32m--- $1 ---\033[0m"
}

function error {
    echo -e "\033[0;31m$1\033[0m"
}

DEBIAN_VERSION=$(cat /etc/debian_version | head -c 2)
DEBIAN_NAME=""
IS_BOOKWORM=false
IS_TRIXIE=false

if [ "${DEBIAN_VERSION}" = "12" ]; then
    IS_BOOKWORM=true
    DEBIAN_NAME="Bookworm"
elif [ "${DEBIAN_VERSION}" = "13" ]; then
    IS_TRIXIE=true
    DEBIAN_NAME="Trixie"
else
    error "Unknown Raspbian version: '${DEBIAN_VERSION}'"
    exit 2
fi

header "Setting up TX-Pi on ${DEBIAN_NAME}"

GIT_TXPI="https://github.com/ftCommunity/tx-pi/raw/master/setup"

INSTALL_DIR="/root/txpi_setup"
FTC_ROOT=$INSTALL_DIR"/ftcommunity-TXT/board/fischertechnik/TXT/rootfs"

# TX-Pi app store
TXPIAPPS_URL="https://github.com/ftCommunity/tx-pi-apps/raw/master/packages/"

# TX-Pi config
TXPICONFIG_DIR="/opt/ftc/apps/system/txpiconfig"


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
    elif [ "$1" == "NODISP" ]; then
        header "Setup without display driver installation"
    else
        error "Unknown parameter \"$1\""
        error "Allowed parameters:"
        error "LCD35    - create 3.5\" setup (instead of 3.2\")"
        error "LCD35B   - create 3.5\" IPS setup"
        error "LCD35BV2 - create 3.5\" IPS rev. 2 setup"
        error "NODISP   - do not install a display driver (Install manually first!)"
        exit 2
    fi
else
   header "Setup for Waveshare 3.2 inch screen"
fi

if [ "$HOSTNAME" == "raspberrypi" ]; then
    msg "Found default hostname, change it to 'tx-pi'"
    raspi-config nonint do_hostname tx-pi
    rm -f /etc/ssh/ssh_host_*
    ssh-keygen -A
fi

rm -rf $INSTALL_DIR

mkdir $INSTALL_DIR

# ----------------------- package installation ---------------------

header "Update Debian"
# Update Debian
apt update && apt --fix-broken -y install && apt -y dist-upgrade
# Installed by default, we don't need them, saves some space, memory, and CPU cycles
apt remove -y --purge modemmanager avahi-daemon firmware-nvidia-graphics \
    firmware-intel-graphics dhcpcd5
apt autoremove -y

header "Install utility libs"
apt -y install --no-install-recommends git mc neovim cmake lighttpd i2c-tools \
        chrony avrdude bluez-tools mpg123 libraspberrypi-dev network-manager

header "Install X11 libs"
apt -y install --no-install-recommends xserver-xorg xinit xserver-xorg-video-fbdev \
        xserver-xorg-legacy unclutter x11vnc xinput-calibrator xserver-xorg-input-evdev 

header "Install Python libs"
apt -y install --no-install-recommends python3 python3-dev python3-pip python3-wheel \
        python3-setuptools python3-pil python3-pyqt5 python3-numpy python3-pexpect \
        python3-smbus python3-rpi.gpio python3-gpiozero python3-bs4 python3-semantic-version \
        python3-websockets python3-opencv

# DHCP client
header "Setup DHCP client"
# Do not try too long to reach the DHCPD server (blocks booting)
sed -i "s/#timeout 60;/timeout 10;/g" /etc/dhcp/dhclient.conf
# By default, the client retries to contact the DHCP server after five min.
# Reduce this time to 20 sec.
sed -i "s/#retry 60;/retry 20;/g" /etc/dhcp/dhclient.conf

# ---------------------- display setup ----------------------
header "Install screen driver"

if [ ${LCD} == "NODISP" ]; then
    header "  --> Skipped by user request <--"
else
    cd $INSTALL_DIR
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
    if [ $LCD == "LCD35BV2" ]; then
        # Support for Waveshare 3.5" "B" rev. 2.0
        sed -i "s/waveshare35b/waveshare35b-v2/g" /boot/config.txt
    fi
fi

# Driver installation changes "console=serial0,115200" to "console=ttyAMA0,115200"
# Revert it here since /dev/ttyAMA0 is Bluetooth (Pi3, Pi3B+ ...)
sed -i "s/=ttyAMA0,/=serial0,/g" /boot/firmware/cmdline.txt
cmd_line=$( cat /boot/firmware/cmdline.txt )
# Driver installation removes "fsck.repair=yes"; revert it
if [[ $cmd_line != *"fsck.repair=yes"* ]]; then
    cmd_line="$cmd_line fsck.repair=yes"
fi
cat <<EOF > /boot/firmware/cmdline.txt
${cmd_line}
EOF


#-- Support for the TX-Pi HAT
header "Enable I2C"
raspi-config nonint do_i2c 0 dtparam=i2c_arm=on
sed -i "s/dtparam=i2c_arm=on/dtparam=i2c_arm=on\ndtparam=i2c_vc=on/g" /boot/firmware/config.txt
# Disable RTC
#TODO: 2025-03-16 -- Bookworm has no rc.local anymore. Is this still necessary?
#sed -i "s/exit 0/\# ack pending RTC wakeup\n\/usr\/sbin\/i2cset -y 0 0x68 0x0f 0x00\n\nexit 0/g" /etc/rc.local
# Power control via GPIO4
echo "dtoverlay=gpio-poweroff,gpiopin=4,active_low=1" >> /boot/firmware/config.txt


header "Enable WLAN"
nmcli radio wifi on


# usbmount config
#TODO 2025-03-16
#cd /etc/usbmount
#wget -N https://raw.githubusercontent.com/ftCommunity/ftcommunity-TXT/3de48278d1260c48a0a20b07a35d14572c6248d3/board/fischertechnik/TXT/rootfs/etc/usbmount/usbmount.conf


# create file indicating that this is a tx-pi setup
touch /etc/tx-pi

# TX-Pi version information
echo "${TX_PI_VERSION}" > /etc/tx-pi-ver.txt


header "Install default locales"
cat <<EOF > /etc/locale.gen
# locales supported by CFW 
en_US.UTF-8 UTF-8
de_DE.UTF-8 UTF-8
nl_NL.UTF-8 UTF-8
fr_FR.UTF-8 UTF-8
EOF

locale-gen
update-locale --no-checks LANG="de_DE.UTF-8"

# fetch bluez hcitool with extended lescan patch
cd $INSTALL_DIR
wget -N $GIT_TXPI/hcitool-xlescan.tgz
tar xvfz hcitool-xlescan.tgz -C /usr/bin

header "Install zbar and zbarlight"
apt -y install --no-install-recommends libzbar0 libzbar-dev
pip3 install --break-system-packages zbarlight

# ----------------------- user setup ---------------------
header "Create ftc user"
groupadd -f ftc
useradd -g ftc -m ftc || true
usermod -a -G video,audio,tty,dialout,input,gpio,i2c,spi,ftc ftc
echo "ftc:ftc" | chpasswd
mkdir -p /home/ftc/apps
chown -R ftc:ftc /home/ftc/apps

# special ftc permissions
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
ftc     ALL = NOPASSWD: /etc/init.d/networking, /sbin/ifup, /sbin/ifdown
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
ftc     ALL = NOPASSWD: ${TXPICONFIG_DIR}/scripts/hostname, ${TXPICONFIG_DIR}/scripts/camera, ${TXPICONFIG_DIR}/scripts/ssh, ${TXPICONFIG_DIR}/scripts/x11vnc, ${TXPICONFIG_DIR}/scripts/display, ${TXPICONFIG_DIR}/scripts/i2cbus, /usr/bin/apt-get
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
cat <<EOF > "/usr/share/X11/xorg.conf.d/99-fbdev.conf"
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
    wget -N $GIT_TXPI/splash.png -O /etc/splash.png
    apt install -y --no-install-recommends libjpeg-dev
    cd $INSTALL_DIR
    wget -N https://github.com/godspeed1989/fbv/archive/master.zip
    unzip -x master.zip
    cd fbv-master/
    FRAMEBUFFER=/dev/fb1 ./configure
    make
    make install
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
cd $INSTALL_DIR
wget -N $GIT_TXPI/fbc.tgz
tar xvfz fbc.tgz
cd fbc
make
cp fbc /usr/bin/

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

msg "Setup VNC server"
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


# set timezone to Germany
ln -fs /usr/share/zoneinfo/Europe/Berlin /etc/localtime
dpkg-reconfigure -f noninteractive tzdata


header "Download FTC firmware"
cd $INSTALL_DIR
git clone --depth 1 https://github.com/ftCommunity/ftcommunity-TXT.git
# set firmware version
mv $FTC_ROOT"/etc/fw-ver.txt" /etc/
# set various udev rules to give ftc user access to hardware
mv $FTC_ROOT"/etc/udev/rules.d/40-fischertechnik_interfaces.rules" /etc/udev/rules.d/
mv $FTC_ROOT"/etc/udev/rules.d/40-lego_interfaces.rules" /etc/udev/rules.d/
mv $FTC_ROOT"/etc/udev/rules.d/60-i2c-tools.rules" /etc/udev/rules.d/
mv $FTC_ROOT"/etc/udev/rules.d/99-USBasp.rules" /etc/udev/rules.d/
mv $FTC_ROOT"/etc/sudoers.d/shutdown" /etc/sudoers.d/
chmod 0440 /etc/sudoers.d/shutdown

# get /opt/ftc
header "Populating /opt/ftc ..."
rm -rf /opt/ftc
mv $FTC_ROOT"/opt/ftc" /opt/ftc
# remove useless ftgui
rm -rf /opt/ftc/apps/system/ftgui
# remove cfw display configuration app since it does not work here...
rm -rf /opt/ftc/apps/system/display/


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


header "Install ftrobopy"
# just fetch a copy of ftrobopy to make some programs happy
wget -N https://raw.githubusercontent.com/ftrobopy/ftrobopy/master/ftrobopy.py -P /opt/ftc

cd $INSTALL_DIR

# install libroboint
header "Installing libroboint"
rm -f /usr/local/lib/libroboint.so*
# install libusb-dev
apt -y install libusb-dev
git clone --depth 1 https://gitlab.com/Humpelstilzchen/libroboint.git
cd libroboint
cmake .
make
# install
make install
ldconfig
# install python
make python
# udev rules
cp udev/fischertechnik.rules /etc/udev/rules.d/

# and ftduino_direct
header "Installing ftduino_direct.py"

# Remove legacy ftduino_direct
rm -f /opt/ftc/ftduino_direct.py
FTDDIRECT="ftduino_direct-1.0.8"
cd $INSTALL_DIR
wget -N https://github.com/PeterDHabermehl/ftduino_direct/raw/master/$FTDDIRECT.tar.gz
tar -xzvf $FTDDIRECT.tar.gz 
cd $FTDDIRECT
python3 ./setup.py install

cd $INSTALL_DIR
git clone --depth 1 https://github.com/harbaum/TouchUI.git
mv ./TouchUI/touchui/apps/system/power /opt/ftc/apps/system/power

# add power tool from touchui
cd /opt/ftc/apps/system
# Move power button to home screen
sed -i "s/category: System/category: /g" /opt/ftc/apps/system/power/manifest

# Add TX-Pi TS-Cal
header "Install TS Cal"
touch /usr/share/X11/xorg.conf.d/99-calibration.conf
chmod og+rw /usr/share/X11/xorg.conf.d/99-calibration.conf
# Remove legacy app
rm -rf /opt/ftc/apps/system/tscal
# Remove any installed TS-Cal
rm -rf /home/ftc/apps/ffe0d8c4-be33-4f62-b25d-2fa7923daaa2
cd /home/ftc/apps
wget "${TXPIAPPS_URL}tscal.zip"
unzip -o tscal.zip -d ffe0d8c4-be33-4f62-b25d-2fa7923daaa2
chown -R ftc:ftc ffe0d8c4-be33-4f62-b25d-2fa7923daaa2
chmod +x ffe0d8c4-be33-4f62-b25d-2fa7923daaa2/tscal.py


# Add TX-Pi config
header "Install TX-Pi config"
# Remove legacy apps and configurations
rm -rf /home/ftc/apps/430d692e-d285-4f05-82fd-a7b3ce9019e5
rm -rf /home/ftc/apps/e7b22a70-7366-4090-b251-5fead780c5a0
rm -f /etc/sudoers.d/sshvnc
# Remove any installed TX-Pi config
rm -rf ${TXPICONFIG_DIR}
mkdir -p "${TXPICONFIG_DIR}"
cd ${TXPICONFIG_DIR}
wget "${TXPIAPPS_URL}config/config.zip"
unzip ./config.zip
chown -R ftc:ftc ${TXPICONFIG_DIR}
chmod +x ${TXPICONFIG_DIR}/config.py
chown root:root ${TXPICONFIG_DIR}/scripts/*
chmod 744 ${TXPICONFIG_DIR}/scripts/*

# add robolt support
# robolt udev rules have already been installed from the main repository
header "Install robolt"
cd $INSTALL_DIR
git clone --depth 1 https://github.com/ftCommunity/python-robolt.git
cd python-robolt
python3 ./setup.py install

# add wedo support
# wedo udev rules have already been installed from the main repository
header "Install WeDoMore"
cd $INSTALL_DIR
git clone --depth 1 https://github.com/gbin/WeDoMore.git
cd WeDoMore
python3 ./setup.py install

# install the BT Control Set server
header "Install BT Control Set server"
apt -y install --no-install-recommends libbluetooth-dev
cd $INSTALL_DIR
git clone  --depth 1 https://github.com/ftCommunity/ft_bt_remote_server.git
cd ft_bt_remote_server
make
make install

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

include_shell "/usr/share/lighttpd/use-ipv6.pl " + server.port
include_shell "/usr/share/lighttpd/create-mime.conf.pl"

index-file.names            = ( "index.py", "index.php", "index.html")
url.access-deny             = ( "~", ".inc" )
static-file.exclude-extensions = ( ".php", ".pl", ".fcgi" )

# default listening port for IPv6 falls back to the IPv4 port

server.modules += ( "mod_ssi" )
ssi.extension = ( ".html" )

server.modules += ( "mod_cgi" )

\$HTTP["url"] =~ "^/cgi-bin/" {
    cgi.assign = ( "" => "" )
}

cgi.assign = (
    ".py"  => "/usr/bin/python3"
)
EOF

# fetch www pages
header "Populating /var/www ..."
rm -rf /var/www
mv $FTC_ROOT"/var/www" /var/www
touch /var/www/tx-pi

# convert most "fischertechnik TXT" texts to "ftcommunity TX-Pi"
cd /var/www
for i in /var/www/*.html /var/www/*.py; do 
    sed -i 's.<div class="outline"><font color="red">fischer</font><font color="#046ab4">technik</font>\&nbsp;<font color="#fcce04">TXT</font></div>.<div class="outline"><font color="red">ft</font><font color="#046ab4">community</font>\&nbsp;<font color="#fcce04">TX-Pi</font></div>.' $i
    sed -i 's.<title>fischertechnik TXT community firmware</title>.<title>ftcommunity TX-Pi</title>.' $i
done

# add VNC and TX-Pi homepage link to index page
sed -i 's#<center><a href="https://github.com/ftCommunity/ftcommunity-TXT" target="ft-community">community edition</a></center>#<center><a href="https://github.com/ftCommunity/ftcommunity-TXT" target="ft-community">ftcommunity</a> - <a href="https://www.tx-pi.de/" target="tx-pi">TX-Pi</a> - <a href="/remote">VNC</a></center>#' /var/www/index.py

# Fav icon
wget -N $GIT_TXPI/favicon.ico

# Install novnc ...
cd /var/www
wget -N $GIT_TXPI/novnc.tgz
tar xvfz novnc.tgz
rm novnc.tgz


# ... and websockify for novnc
cd /opt/ftc
wget -N $GIT_TXPI/websockify.tgz
tar xvfz websockify.tgz
rm websockify.tgz

# systemd (tmpfiles.d) resets the permissions to www-data if the
# system reboots. This ensures that the permissions are kept alive.
sed -i "s/www-data/ftc/g" /usr/lib/tmpfiles.d/lighttpd.tmpfile.conf

# adjust file ownership for changed www user name
chown -R ftc:ftc /var/www
chown -R ftc:ftc /var/log/lighttpd
chown -R ftc:ftc /var/run/lighttpd
chown -R ftc:ftc /var/cache/lighttpd


header "Install fb grab"
# fbgrab needs netpbm to generate png files
apt -y install netpbm

apt -y install --no-install-recommends fbcat
sed -i 's.fbgrab.fbgrab -d /dev/fb1.' /var/www/screenshot.py

# disable the TXTs default touchscreen timeout as the waveshare isn't half
# as bad as the TXTs one
cat <<EOF > /home/ftc/.launcher.config 
[view]
min_click_time = 0
EOF
chown ftc:ftc /home/ftc/.launcher.config 


header "Add default TX-Pi stores"
cat <<EOF > /home/ftc/.repositories.xml
<repositories>
  <repository name="TX-Pi Apps" repo="tx-pi-apps" user="ftCommunity"/>
  <repository name="Till&apos;s Apps" repo="cfw-apps" user="harbaum"/>
</repositories>
EOF


apt -y autoremove


if [ "$DEBUG" = false ]; then
   msg "Cleaning up"
   rm -rf $INSTALL_DIR
else
   msg "Running in debug mode, keeping ${INSTALL_DIR}"
fi

msg "rebooting in 30 sec..."
sync
sleep 30
shutdown -r now
