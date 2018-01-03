# TX-PI - A Raspberry PI setup for fischertechnik

This repository contains the basic requirements to make a Raspberry Pi
hardware and software compatible with the [community firmware
for the fischertechnik TXT](http://cfw.ftcommunity.de/).

<img src="https://raw.githubusercontent.com/harbaum/tx-pi/master/images/display32_1.jpg" alt="TX-PI" width="400" style="width: 400px;"/>

# Requirements

You'll need:

  - a Raspberry Pi B+, 2 or 3
  - a Waveshare 3.2" LCD touchscreen (either V3 or V4)
  - a micro SD card with at least 8GB space

Optionally build the [PiPower](https://github.com/harbaum/tx-pi/tree/master/pipower) to supply the Pi from fischertechnik power sources.

# Hardware setup

The case consists of four parts. A bottom and top part for each the
Pi itself and the display. Both parts can be connected to each other
using ordinary fischertechnik parts.

3D print the four case parts. The connector height of the display
differs between V3 and V4. The required screws are M2.5 * 12mm
countersunk.

# Software setup

The entire installation consists of three main steps:

  1. Installing a standard raspbian operating system imade on an SD card
  2. Doing some minor manual preparations
  3. Run a script that will do all the tx-pi specific modifications

## Step 1: Install Raspbian on SD card

Get am SD card image of [Raspbian Jessie
Lite](http://downloads.raspberrypi.org/raspbian_lite/images/raspbian_lite-2017-07-05/)
and install it onto SD card. More information on installinf rasbian on
an SD card can be found
[here](https://www.raspberrypi.org/documentation/installation/installing-images/README.md).

Insert the SD card into your Pi and boot it. Unless you are very
familiar with the Pi and are able to do a headless setup you should
have a keyboard and HDMI display connected to the Pi.

## Step 2: Do some manual preparations

Now log into your pi using the keyboard and the screen. The login is
"pi" and the password is "raspberry" as with any raspian installation.

Start the raspi-config tool by typing ```sudo raspi-config``` and
perform the following things:

  1. Change the hostname to ```tx-pi```
  2. Disable "wait for network" in the ```Boot Options```

Leave the raspi-config tool and shutdown the Pi by typing ```sudo
shutdown -h now```. You don't necessarily need the keyboard and HDMI
display anymore and you might remove it. Instead connect the small 3.2
inch LCD if you haven't yet done so.

Start your Pi again.

## Step 3: The TX-Pi setup

Again log into your Pi and once more use use the login ```pi``` and
the password ```raspberry```.

Now download the setup script by typing:

```
wget https://raw.githubusercontent.com/harbaum/tx-pi/master/setup/tx-pi-setup.sh
```

and run the script by typing
```
sudo bash ./tx-pi-setup.sh
```

This will now take several hours and download and install a lot of
programs from the internet onto your Pi. Once the installation is done
your Pi will automatically reboot and it will boot into the user
interface of the [fischertechnik community
firmware](http://cfw.ftcommunity.de/)..

## Disclaimer

This is a work in progress. Some parts aren't working by now and some may
be broken. But the project is progressing fast and most functionality is
working.
