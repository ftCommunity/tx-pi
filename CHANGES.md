# Changes

## 2020-mm-dd
* Removed support for Debian Jessie (v8)
* Added support for Debian Buster (v10)
* Removed support of netreq for Buster since its purpose is uncertain,
  see <https://github.com/ftCommunity/tx-pi/issues/23>
* Setup enables I2C by default
* Setup enables WLAN support by default
* Added <https://github.com/harbaum/cfw-apps> as App-Shop URL


## 2019-05-04
* Recommending Raspbian Stretch as default setup
* Updated TS-Cal (fixes issue #39)
* Changed TX-Pi logo / splash screen
* Added TX-Pi config application which can be used to configure the
  hostname, display etc. (fixes issues #31, #32, and #33) 
* Replaced "SSH / VNC" app with "TX-Pi config" app
* Use "TX-Pi" instead of "TX-PI" in web UI
* Added support for Waveshare 3.5" B revision 2 displays (fixes issue #37).
  Thanks to Peter Sterk, who generously donated a display!
* The Waveshare setup removes ``fsck.repair=yes`` from ``/boot/cmdline.txt`` 
  (Stretch). Reactivate it.
* Updated TouchUI to detect TX-Pi to avoid an error due to the missing
  (TXT) hardware button. See issue #35
* Fixed timezone setup (Stretch)


## 2019-03-24
* Decouple VNC service from X service (VNC can be disabled independently from X)
* Fixed: NetReq service blocks systemd
* Experimental support to enable / disable SSH and VNC via app
* Ensure that Python wheel package is available.
* Move Power-Off app to homescreen
