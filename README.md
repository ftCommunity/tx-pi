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

Optionally build the [PiPower](https://github.com/harbaum/tx-pi/tree/master/pipower) to supply the Pi from fischertechnik power sources.

## Hardware setup

The case consists of four parts. A bottom and top part for each the
Pi itself and the display. Both parts can be connected to each other
using ordinary fischertechnik parts.

3D print the four case parts. The connector height of the display
differs between V3 and V4. The required screws are M2.5 * 12mm
countersunk.

## Operating system setup

Get the latest [Raspbian Jessie Lite](http://downloads.raspberrypi.org/raspbian_lite/images/raspbian_lite-2017-07-05/) and install it onto SD card. Boot your PI with it and do a few things using raspi-config:

  - Enable networking so the Pi can access the internet
    - If you need to use WiFi, see [this article](https://thepihut.com/blogs/raspberry-pi-tutorials/83502916-how-to-setup-wifi-on-raspbian-jessie-lite) on how to set up
  - Set the hostname to tx-pi
  - Expand the file system (under advanced options)
  - Disable "wait for network" boot option
  - It is recommended to also enable ssh for easier acces to your tx-pi later
  - Reboot after your changes
    
Step by Step installation of the setup script:
 
  After reboot, it is recommended to update the raspi now, because the display driver may cause problems after updates.
  - sudo apt-get update
  - sudo apt-get upgrade
  
  In case your display does not work after reboot, you can try removing the statement: dtoverlay=ads7846 from the LCD-show32.txt-90 config file (in /LCD-show/boot) (see Waveshare Wiki: http://www.waveshare.com/wiki/3.2inch_RPi_LCD_(B))
  
  At this point you've finished the preparation of the RPi operating system.

## TX-Pi software setup
  
  Now download and start the [setup script](https://raw.githubusercontent.com/harbaum/tx-pi/master/setup/tx-pi-setup.sh) onto your PI (at this point, you might be happy to have *ssh* available) and run it as *sudo*. It will download and install the display drivers as well as major parts of the community firmware.
  You might log in as user "pi", since the TX-Pi default user "ftc" has no sudo rights by default.
  
  - ssh pi@"ip address of the TX-Pi"
  
  Then via ssh:  
  - cd..
  - sudo wget https://raw.githubusercontent.com/harbaum/tx-pi/master/setup/tx-pi-setup.sh
  - sudo chmod +x ./tx-pi-setup.sh
  - sudo ./tx-pi-setup.sh

During display driver installation the pi will reboot (at that point, the ssh connection will be closed) and you'll have to start
the script a second time to allow it to finish the setup:

  - ssh pi@<ip address of the TX-Pi>
  
  Then via ssh:  
  - cd..
  - sudo ./tx-pi-setup.sh

The script then runs some time, but building of opencv2 for python3 is no longer necessary. Pre-built packages for opencv2 and bluez will be downloaded from this repository.

[libroboint](https://defiant.homedns.org/~erik/ft/libft/) for C and Python will be built during the install process. Libroboint Python3 support is experimental. Anyway TX-PI now can control ft Robo Interface and Robo I/O Extention, especially in combination with TouchUI under Python3.
Additionally, the python library of [ftduino_direct](https://github.com/PeterDHabermehl/ftduino_direct) will be installed to the TX-Pi, in case you would like to use the ftduino as I/O hardware extension to your TX-Pi.

*If you want to update your TX-Pi, just repeat the steps described under "TX-Pi software setup"*

This is a work in progress. Some parts aren't working by now.
