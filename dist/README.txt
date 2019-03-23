
# Duplicating and distributing TX-Pi images

The entire setup process takes some time and is rather complex. It's thus
helpful to be able to copy and redistribute the result.

The [PiShrink](https://github.com/harbaum/PiShrink) script allows you
to create an installable SD card image from a working TX-Pi setup.

```
# read image from SD card reader
sudo cp /dev/sdb tx-pi-fullsize.img
# shrink image
sudo ./pishrink.sh -c tx-pi-fullsize.img tx-pi.img
```
Afterwards, you have to apply the [preparetxpidist.sh](https://github.com/ftCommunity/tx-pi/raw/master/dist/preparetxpidist.sh) script to the tx-pi.img:

```
preparetxpidist.sh tx-pi.img
```

This script modifies the image. Do not apply the script to the same image twice!

The resulting image ```tx-pi.img``` can be copied to another SD card and
will resize itself on first boot and generate new SSH keys etc.
