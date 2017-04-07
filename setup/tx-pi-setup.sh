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
# - adjust font size
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
apt-get -y install --no-install-recommends xserver-xorg xinit xserver-xorg-video-fbdev xserver-xorg-legacy
# python and pyqt
apt-get -y install --no-install-recommends python3-pyqt4 python3 python3-pip python3-numpy python3-dev cmake python3-serial python3-pexpect
# misc tools
apt-get -y install i2c-tools lighttpd git subversion ntpdate

# some additionl python stuff
pip3 install semantic_version
pip3 install websockets
pip3 install pyserial

# ---------------------- display setup ----------------------
# check if waveshare driver is installed
if [ ! -f /boot/overlays/waveshare32b-overlay.dtb ]; then
    echo "============================================================"
    echo "============== SCREEN DRIVER INSTALLATION =================="
    echo "============================================================"
    echo "= YOU NEED TO RESTART THIS SCRIPT ONCE THE PI HAS REBOOTED ="
    echo "============================================================"
    cd
    wget -N http://www.waveshare.com/w/upload/7/74/LCD-show-170309.tar.gz
    tar xvfz LCD-show-170309.tar.gz
    cd LCD-show
    ./LCD32-show
    # the pi will reboot
fi

# create locales
cat <<EOF > /etc/locale.gen
# locales supported by CFW 
en_US.UTF-8 UTF-8
de_DE.UTF-8 UTF-8
nl_NL.UTF-8 UTF-8
fr_FR.UTF-8 UTF-8
EOF
locale-gen

# fetch bluez with extended lescan patch
wget https://github.com/harbaum/tx-pi/raw/master/packages/bluez_5.23-2-xlescan_armhf.deb
dpkg -i bluez_5.23-2-xlescan_armhf.deb

# fetch precompiled opencv and its dependencies
# we might build our own package to get rid of these dependencies,
# especially gtk
apt-get install libjasper1 libgtk2.0-0 libavcodec56 libavformat56 libswscale3
wget https://github.com/jabelone/OpenCV-for-Pi/raw/master/latest-OpenCV.deb
dpkg -i latest-OpenCV.deb

# ----------------------- user setup ---------------------
# create ftc user
groupadd ftc
useradd -g ftc -m ftc
usermod -a -G video ftc
usermod -a -G tty ftc
usermod -a -G dialout ftc
usermod -a -G input ftc
echo "ftc:ftc" | chpasswd

# special ftc permissions
cd /etc/sudoers.d
wget -N $GITROOT/etc/sudoers.d/shutdown
chmod 0440 /etc/sudoers.d/shutdown
cat <<EOF > /etc/sudoers.d/bluetooth
## Permissions for ftc access to programs required
## for bluetooth setup

ftc     ALL = NOPASSWD: /usr/bin/hcitool, /etc/init.d/bluetooth, /usr//bin/pkill -SIGINT hcitool
EOF
chmod 0440 /etc/sudoers.d/bluetooth
cat <<EOF > /etc/sudoers.d/wifi
## Permissions for ftc access to programs required
## for wifi setup
ftc     ALL = NOPASSWD: /sbin/wpa_cli
EOF
chmod 0440 /etc/sudoers.d/wifi

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

# hide cursor and disable screensaver
cat <<EOF > /etc/X11/xinit/xserverrc
#!/bin/sh
exec /usr/bin/X -s 0 dpms -nocursor -nolisten tcp "\$@"
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
wget -N $GITROOT/etc/udev/rules.d/40-btsmart.rules
wget -N $GITROOT/etc/udev/rules.d/40-robolt.rules
wget -N $GITROOT/etc/udev/rules.d/40-wedo.rules
wget -N $GITROOT/etc/udev/rules.d/60-i2c-tools.rules

# get /opt/ftc
echo "Populating /opt/ftc ..."
cd /opt
rm -rf ftc
svn export $SVNROOT"/opt/ftc"
cd /opt/ftc
# just fetch a copy of ftrobopy to make some programs happy
wget -N https://raw.githubusercontent.com/ftrobopy/ftrobopy/master/ftrobopy.py

# remove usedless ftgui
rm -rf /opt/ftc/apps/system/ftgui

# add power tool from touchui
cd /opt/ftc/apps/system
svn export $TSVNBASE"/touchui/apps/system/power"

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

# adjust file ownership for changed www user name
chown -R ftc:ftc /var/www/*
chown -R ftc:ftc /var/log/lighttpd
chown -R ftc:ftc /var/run/lighttpd
chown -R ftc:ftc /var/cache/lighttpd

#mkdir /opt/ftc/apps/user
#chown -R ftc:ftc /opt/ftc/apps/user

mkdir /home/ftc/apps
chown -R ftc:ftc /home/ftc/apps

/etc/init.d/lighttpd restart

echo "rebooting ..."

sync
reboot
