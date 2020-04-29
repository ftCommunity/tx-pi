# ft PiPower

This is a design for a very cheap and simple power adapter. It converts
the approx. 9V DC typically used with fischertechnik models to the 5V required by
the raspberry pi.

![PiPower in use](https://raw.githubusercontent.com/harbaum/tx-pi/master/images/pipower_use.jpg)

The PiPower mainly consists of one of those ubiquitous LM2596 based
DC-DC converters which can easily be found on ebay and similar sites.

For the connection on fischertechnik side two flush sleeve of 8.4mm
length ([Bundhülsen](https://knobloch-gmbh.de/de/bundhuelse-zum-einloeten-l-8-4)) are being used.

The connection to the Raspberry Pi is done via some short micro USB cable.
The Delock 82697 works nicely but you can also cut any ordinary micro USB
cable.

![PiPower parts](https://raw.githubusercontent.com/harbaum/tx-pi/master/images/pipower_parts.jpg)

The flush sleeves and the cable are soldered to the DC-DC converter
and everything is placed in the case. The cable can additionally be
secured to the case using a cable tie. Provide power to the adapter
and use a screwdriver to adjust the output voltage to 5V. Once done
close the case using two M3 (3mm) flat head screws with 6-8mm length.

![PiPower assembled](https://raw.githubusercontent.com/harbaum/tx-pi/master/images/pipower_assembled.jpg)

| Top | Bottom |
|:---:|:---:|
| ![Top](../images/stl/pipower/top.png) | ![Bottom](../images/stl/pipower/bottom.png) |
| [View](top.stl) | [View](bottom.stl) |
| [Download](top.stl?raw=true) | [Download](bottom.stl?raw=true) |
