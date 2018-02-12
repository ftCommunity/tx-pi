# TX-PI - A Raspberry PI setup for fischertechnik

This repository contains the basic requirements to make a Raspberry Pi
hardware and software compatible with the [community firmware
for the fischertechnik TXT](http://cfw.ftcommunity.de/).

The image below show a TX-Pi-XL (with 3.5" display) using an
[ftDuino](https://github.com/harbaum/ftduino) to connect to 
fischertechnik actors and sensors.

<img src="https://raw.githubusercontent.com/harbaum/tx-pi/master/images/tx-pi-xl+ftduino.jpg" alt="TX-PI"/>

# Features and Highlights

  - Runs on any Raspberry Pi
  - User friendly touchscreen GUI for small add-on screens
    - Waveshare 3.2" and 3.5" tested
    - Screen mirroring onto the "big screen" for demos and bigger audiences
    - Automatic detection and unsage of keyboards and mice
  - System tools for network configuration etc
  - Support for various USB or Bluetooth attached fischertechnik interfaces
    - Robo Interface
    - Robo I/O extension
    - Robo LT
    - BT Smart Controller
    - BT Remote Control Receiver and Sender
    - fischertechnik 3D printer
    - ftDuino
    - Lego WeDo 1.0
    - Lego WeDo 2.0
  - Integrated app store for the ft community firmware

# Videos and more information

See the TX-Pi in action at:
  - [TX-Pi and ftDuino with startIDE](https://www.youtube.com/watch?v=IHZensWPgkA)
  - [TX-Pi and Robo I/O extension](https://www.youtube.com/watch?v=PvvbSaEjqx4)
  - [TX-Pi controlling an ft 3D printer](https://www.youtube.com/watch?v=7q1lq7Kb-jw)
  - [Tx-Pi controlling the ft BT Smart Controller](https://www.youtube.com/watch?v=4NIjJu--a9E)

There's also a [thread in the fischertechnik community forum](https://forum.ftcommunity.de/viewtopic.php?f=33&t=4198) about the TX-Pi.

# Requirements

You'll need:

  - a Raspberry Pi B+, 2 or 3
  - a Waveshare 3.2" LCD touchscreen (either V3 or V4) (see below for 3.5" support)
  - a micro SD card with at least 8GB space

Optionally you might use matching [ft compatible cases](https://www.thingiverse.com/thing:2217355) and the [PiPower](https://github.com/harbaum/tx-pi/tree/master/pipower) to supply the Pi from fischertechnik power sources.

In case you do not want to use the 3D printed case, you might opt for a wide variety of standard RPi cases  suited for the LCD touchscreen. See the image below for how this might look like:
<img src="https://raw.githubusercontent.com/harbaum/tx-pi/master/images/TX-Pi-light-small.jpg" alt="TX-PI in standard case"/>

# Hardware setup

The case consists of four parts. A [bottom](https://www.thingiverse.com/thing:2217355) and [top](https://www.thingiverse.com/thing:2228623) part for Pi and a [bottom](https://www.thingiverse.com/thing:2228649) and [top](https://www.thingiverse.com/thing:2228655) part for the 
display. Both parts can be connected to each other
using ordinary fischertechnik parts.

The connector height of the display differs between V3 and V4 and the V3 display needs a [higher bottom part](ps://www.thingiverse.com/thing:2228635).

The required screws are M2.5 * 12mm countersunk.

# Software setup

The entire installation consists of three main steps:

  1. Install a standard raspbian operating system image onto SD card
  2. Do some minor manual preparations
  3. Run a script that will do all the tx-pi specific modifications

## Step 1: Install Raspbian onto SD card

Get an SD card image of [Raspbian Jessie
Lite](http://downloads.raspberrypi.org/raspbian_lite/images/raspbian_lite-2017-07-05/)
and install it onto SD card. More information on installing rasbian on
SD card can be found [here](https://www.raspberrypi.org/documentation/installation/installing-images/README.md).

Insert the SD card into your Pi and boot it. Unless you are very
familiar with the Pi and are able to do a headless setup you should
have a keyboard and HDMI display connected to the Pi.

## Step 2: Do some manual preparations

Now log into your pi using the keyboard and the screen. The login is
"pi" and the password is "raspberry" as with any raspian installation.

Start the raspi-config tool by typing ```sudo raspi-config``` and
perform the following things:

  1. Change the hostname to ```tx-pi``` or something similar
  2. Disable "wait for network" in the ```Boot Options```

Leave the raspi-config tool and shutdown the Pi by typing ```sudo
shutdown -h now```. Connect the small 3.2 inch LCD if you haven't yet
done so.

Start your Pi again.

## Step 3: Run the TX-Pi setup

Again log into your Pi and once more use use the login ```pi``` and
the password ```raspberry```.

Now download the setup script by typing:

```
wget goo.gl/VXvDML -O tx-pi-setup.sh
```

and run the script by typing
```
sudo bash ./tx-pi-setup.sh
```

This will now take about one hour and download and install a lot of
programs from the internet onto your Pi. Once the installation is done
your Pi will automatically reboot and it will boot into the user
interface of the [fischertechnik community
firmware](http://cfw.ftcommunity.de/)..

<img src="https://raw.githubusercontent.com/harbaum/tx-pi/master/images/display32.png" alt="3.2 inch display"/>

# Support for 3.5" screens

The TX-Pi also supports the 3.5" TFT displays from Waveshare. To
configure TX-Pi for one of these instead of the default 3.2" version
the install script has to be invoked with a special option.

If you use the regular (A) type display from waveshare:
```
sudo bash ./tx-pi-setup.sh LCD35
```

and if you have the IPS (B) type display:
```
sudo bash ./tx-pi-setup.sh LCD35B
```

The 3.5" display has a resolution of 320x480 pixel while the 3.2" display
and the display of the fischertechnik TXT only provide 240x320 pixels. Thus
some apps written for the TXT or the regular TX-Pi setup may look a little
different. But due to the Qt framework most apps will just look fine.

<img src="https://raw.githubusercontent.com/harbaum/tx-pi/master/images/display35.png" alt="3.5 inch display"/>

## Tweaking the display performance

The 3.5" display are driven by a 16 MHz data clock by default which results
in a rather poor redraw performance. This can be increased by setting
the SPI clock to a higher value. E.g. to set it to 40Mhz change the line
in /boot/config.txt:
```
dtoverlay=waveshare35a:rotate=180,speed=40000000
```

You can also change the screen orientation by changing the 
```ORIENTATION``` value in line 35 of the ```tx-pi-setup.sh``` script
before running it.

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

The resulting image ```tx-pi.img``` can be copied to another SD card and
will resize itself on first boot and generate new SSH keys etc.

# Disclaimer

This is a work in progress. Some parts aren't working by now and some may
be broken. But the project is progressing fast and most functionality is
working.
