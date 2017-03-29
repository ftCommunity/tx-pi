#!/bin/bash
# to be run on plain jessie-lite
echo "Setting up TX-PI on jessie lite ..."

GITBASE="https://raw.githubusercontent.com/ftCommunity/ftcommunity-TXT/master/"
GITROOT=$GITBASE"board/fischertechnik/TXT/rootfs"
SVNBASE="https://github.com/ftCommunity/ftcommunity-TXT.git/trunk/"
SVNROOT=$SVNBASE"board/fischertechnik/TXT/rootfs"

# Things you may do:
# set a root password
# enable root ssh login
# apt-get install emacs-nox

if [ "$HOSTNAME" != tx-pi ]; then
    echo "Make sure your R-Pi has been setup completely and is named tx-pi"
    exit -1
fi

# create ftc user
#groupadd ftc
#useradd -g ftc -m ftc
echo "ftc:ftc" | chpasswd

# install
# -------
# misc tools
#apt-get -y install i2c-tools lighttpd git subversion
# X11
#apt-get -y install --no-install-recommends xserver-xorg xinit xserver-xorg-video-fbdev
# python and pyqt
# apt-get -y install --no-install-recommends python3-pyqt4 python3

# getch /opt/ftc
echo "Populating /opt/ftc ..."
cd /opt
#rm -rf ftc
#svn export $SVNROOT"/opt/ftc"

# adjust lighttpd config
sed -i 's,^\(server.document-root *=\).*,\1'\ \"/var/www\"',' /etc/lighttpd/lighttpd.conf
sed -i 's,^\(server.username *=\).*,\1'\ \"ftc\"',' /etc/lighttpd/lighttpd.conf
sed -i 's,^\(server.groupname *=\).*,\1'\ \"ftc\"',' /etc/lighttpd/lighttpd.conf

# enable ssi
if ! grep -q mod_ssi /etc/lighttpd/lighttpd.conf; then
cat <<EOF >> /etc/lighttpd/lighttpd.conf

server.modules += ( "mod_ssi" )
ssi.extension = ( ".html" )
EOF
fi

# enable cgi
if ! grep -q mod_cgi /etc/lighttpd/lighttpd.conf; then
cat <<EOF >> /etc/lighttpd/lighttpd.conf
server.modules += ( "mod_cgi" )

\$HTTP["url"] =~ "^/cgi-bin/" {
       cgi.assign = ( "" => "" )
}

cgi.assign      = (
       ".py"  => "/usr/bin/python3"
)
EOF
fi
    
#    echo "server.modules += ( \"mod_cgi\" )" >> /etc/lighttpd/lighttpd.conf
#    echo "\$HTTP[\"url\"] =~ \"^/cgi-bin/\" {" >> /etc/lighttpd/lighttpd.conf
#    echo "        cgi.assign = ( \"\" => \"\" )" >> /etc/lighttpd/lighttpd.conf
#    echo "}" >> /etc/lighttpd/lighttpd.conf
#    echo "cgi.assign      = (" >> /etc/lighttpd/lighttpd.conf
#    echo "    \".py\"  => \"/usr/bin/python3\"," >> /etc/lighttpd/lighttpd.conf
#    echo ")" >> /etc/lighttpd/lighttpd.conf

#cat <<EOF >> /etc/lighttpd/lighttpd.conf
#server.modules += ( "mod_ssi" )
#EOF

# fetch www pages
echo "Populating /var/www ..."
cd /var
#rm -rf www
#svn export $SVNROOT"/var/www"

# adjust file ownership for changed www user name
chown -R ftc:ftc /var/www/*
chown -R ftc:ftc /var/log/lighttpd
chown -R ftc:ftc /var/run/lighttpd

/etc/init.d/lighttpd restart

# remove
# ------

## wget file by file ...
##cd /var/www
##PAGES="index.html txt.css favicon.ico appinfo.py applist.py applog.py brick-gif delete.py icon.png laun#ch.py screenshot.html screenshot.png screenshot.py stop.py upload.py"
##for page in $PAGES; do
##    URL=$BASEURL"board/fischertechnik/TXT/rootfs/var/www/"$page
##    echo "Fetching $URL ..."
##    wget -N $URL
##done

