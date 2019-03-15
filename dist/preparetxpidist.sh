#!/bin/bash
#
# Script to prepare a TX-Pi distribution.
#
# This script ensures that sensible data is removed from the distribution image
# and prepares the distribution for the first boot process.
#
# The script "pishrink.sh" <https://github.com/harbaum/PiShrink> should have
# been used to create the distribution image.
#
# It's not necessary to invoke pishrink with the "clean" option, since
# this script undertakes the same cleaning steps.
#

img=$1

was_kpartx_available=true
which kpartx 2>&1 > /dev/null
if (( $? != 0 )); then
    echo "Installing kpartx (will be removed afterwards)"
    was_kpartx_available=false
    apt-get -y install kpartx
fi

loop_res=$(kpartx -asv $img)
loop_names=( $(echo $loop_res | grep -o 'loop[0-9a-z]\+') )

#
# Handle "boot" partition
#
mount_dir=$(mktemp -d)
mount /dev/mapper/${loop_names[0]} "${mount_dir}" -o loop,rw

echo "Removing SSH and WLAN config (if any)"
rm -f -v ${mount_dir}/ssh
rm -f -v ${mount_dir}/wpa_supplicant.conf
# Remove OSX spefiic files. They do no harm, though
rm -rf -v ${mount_dir}/._.Trashes ${mount_dir}/.Trashes/
umount "${mount_dir}"


#
# Handle OS partition
#
mount_dir=$(mktemp -d)
mount /dev/mapper/${loop_names[1]} "${mount_dir}" -o loop,rw

echo "Resetting WLAN configuration (if any)"
cat <<EOF > ${mount_dir}/etc/wpa_supplicant/wpa_supplicant.conf
ctrl_interface=DIR=/var/run/wpa_supplicant GROUP=netdev
update_config=1
EOF

echo "Remove log files"
# cleanup apt cache
rm -f -v ${mount_dir}/var/cache/apt/archives/*.deb
rm -f -v ${mount_dir}/var/cache/apt/archives/partial/*
# remove log files
rm -f -v ${mount_dir}/var/log/*.log
rm -f -v ${mount_dir}/var/log/apt/*

echo "Removing SSH host keys"
rm -f -v ${mount_dir}/etc/ssh/ssh_host_*

echo "Replace launcher service temporarily"
launcher_py=/opt/ftc/launcher.py
mv ${mount_dir}${launcher_py} ${mount_dir}${launcher_py}.bak
cat <<EOF > ${mount_dir}${launcher_py}
#!/bin/bash
#
# Temporarily replacement for the launcher.py. Will be deleted after first boot
#

fbv -e /etc/splash.png
EOF

chmod +x ${mount_dir}${launcher_py}

# Create tmp. splash screen
splash_png="/etc/splash.png"
cp ${mount_dir}${splash_png} ${mount_dir}${splash_png}.bak
convert -pointsize 20 -fill yellow -draw 'text 45,200 "Preparing device" ' ${mount_dir}${splash_png} ${mount_dir}${splash_png}

# Enable /boot/wpa_supplicant.conf
echo "Restoring wpa_supplicant.conf support"
cat << 'EOF' > ${mount_dir}/etc/network/if-pre-up.d/00-wpa-config-copy
#!/bin/sh
#
# Script to install /boot/wpa_supplicant.conf
#
mount_dir=$(mktemp -d)
mount -n -t vfat /dev/mmcblk0p1 "$mount_dir" -o rw

# Configure WIFI
boot_wifi=$mount_dir/wpa_supplicant.conf
if [ -f "$boot_wifi" ]; then
    mv -f $boot_wifi /etc/wpa_supplicant/wpa_supplicant.conf
    chmod 600 /etc/wpa_supplicant/wpa_supplicant.conf
fi

# Check if /boot/ssh is available.
# The file will be removed by the ssh.switch service we'll restore it in rc.local
# so it becomes available after the reboot to give the SSH server a 2nd chance
boot_ssh=$mount_dir/ssh
if [ -f "$boot_ssh" ]; then
    touch $mount_dir/enable_ssh
fi

umount /dev/mmcblk0p1

# Removes itself
rm -f /etc/network/if-pre-up.d/00-wpa-config-copy

exit 0
EOF

chmod +x ${mount_dir}/etc/network/if-pre-up.d/00-wpa-config-copy

additional_commands=$(cat << 'EOF'
#
#  Additional instructions
#

# Mount /boot partition
mount_dir=$(mktemp -d)
mount -n -t vfat /dev/mmcblk0p1 "${mount_dir}" -o rw

# Check if a enable_ssh was created by network if-pre.up
enable_ssh=${mount_dir}/enable_ssh
if [ -f "$enable_ssh" ]; then
    touch ${mount_dir}/ssh
    rm -f ${enable_ssh}
fi

umount /dev/mmcblk0p1

# Generate new SSH keys
rm -f /etc/ssh/ssh_host_*
ssh-keygen -A

# Install the default splash screen
mv /etc/splash.png.bak /etc/splash.png

# Install default launcher
mv /opt/ftc/launcher.py.bak /opt/ftc/launcher.py

#
#  End of additional instructions
#
EOF
)

sed -i "s|^#!/bin/bash|#!/bin/bash\n${additional_commands//$'\n'/\\n}|" "${mount_dir}/etc/rc.local"

umount "${mount_dir}"

kpartx -d $img

if [ "$was_kpartx_available" = false ]; then
    echo "Removing kpartx"
    apt-get -y remove kpartx
fi
