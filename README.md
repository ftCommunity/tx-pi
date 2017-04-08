# TX-PI - A Raspberry PI setup for fischertechnik

This repository contains the basic requirements to make a Raspberry Pi
hardware and software compatible with the [community firmware
for the fischertechnik TXT](http://cfw.ftcommunity.de/).

<img src="https://raw.githubusercontent.com/harbaum/tx-pi/master/images/display32_1.jpg" alt="TX-PI" width="400" style="width: 400px;"/>

# Getting started

You'll need:

  - a Raspberry Pi 2 or 3
  - a Waveshare 3.2" LCD touchscreen (either V3 or V4)
  - a micro SD card with at least 8GB space

## Hardware setup

The case consists of four parts. A bottom and top part for each the
Pi itself and the display. Both parts can be connected to each other
using ordinary fischertechnik parts.

3D print the four case parts. The connector height of the display
differs between V3 and V4. The required screws are M2.5 * 12mm
countersunk.

## Software setup

Get the latest [Raspbian Jessie Lite](https://www.raspberrypi.org/downloads/raspbian/) and install it onto SD card. Boot your PI with it and do a few things using raspi-config:

  - Enable networking so the Pi can access the internet
    - If you need to use WiFi, see [this article](https://thepihut.com/blogs/raspberry-pi-tutorials/83502916-how-to-setup-wifi-on-raspbian-jessie-lite) on how to set up
  - Set the hostname to tx-pi
  - Expand the file system (under advanced options)
  - Disable "wait for network" boot option
  - You might also want to enable ssh for easier acces to your tx-pi later

Now download the [setup script](https://raw.githubusercontent.com/harbaum/tx-pi/master/setup/tx-pi-setup.sh) onto your PI (at this point, you might be happy to have *ssh*, or more precise, *scp* available) and run it as *sudo*. It will
download and install the display drivers as well as major parts of
the community firmware.

During display driver installation the pi will reboot and you'll have to start
the script a second time to allow it to finish the setup.

The script then runs some time, but building of opencv2 for python3 is no longer necessary. Pre-built packages for opencv2 and bluez will be downloaded from this repository.

This is a work in progress. Some parts aren't working by now.
