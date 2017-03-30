# TX-PI - A Raspberry PI setup for fischertechnik

This repository contains the basic requirements to make a Raspberry Pi
mechanically and software compatible with the [community firmware
for the fischertechnik TXT](http://cfw.ftcommunity.de/).

<img src="https://raw.githubusercontent.com/harbaum/tx-pi/master/images/display32_1.jpg" alt="TX-PI" width="400" style="width: 400px;"/>

# Getting started

You'll need:

  - a Raspberry Pi 2 or 3
  - a Waveshare 3.2" LCD touchscreen (either V3 or V4)

## Hardware setup

The case consists of four parts. A bottom and top part for each the
Pi itself and the display. Both parts can be connected to each other
using ordinary fischertechnik parts.

3D print the four case parts. The connector height of the display
differs between V3 and V4. The required screws are M2.5 * 12mm
countersunk.

## Software setup

Get the latest [Raspbian Jessie Lite](https://www.raspberrypi.org/downloads/raspbian/) and install it onto SD card. Boot your PI with it and do two things:

  - Enable networking so the Pi can access the internet
  - Set the hostname to tx-pi

Now download the [setup script](https://raw.githubusercontent.com/harbaum/tx-pi/master/setup/tx-pi-setup.sh) onto your PI and run it. It will
download and install the display drivers as well as majaor parts of
the community firmware.

During display driver installation the pi will reboot and you'll have to start
the script a second time to allow it to finish the setup.

This is a work in progress. Some parts aren't working by now.
