# Changes


## 2019-mm-dd
* The Waveshare setup removes ``fsck.repair=yes`` from ``/boot/cmdline.txt`` 
  (Stretch). Reenable it.
* Updated TouchUI to detect TX-Pi to avoid an error due to the missing
  hardware button (TXT). See issue #35
* Fixed timezone setup (Stretch)


## 2019-03-24
* Decouple VNC service from X service (VNC can be disabled independently from X)
* Fixed: NetReq service blocks systemd
* Experimental support to enable / disable SSH and VNC via app
* Ensure that Python wheel package is available.
* Move Power-Off app to homescreen
