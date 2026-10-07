# ‘Geek szitman supercamera’ viewer

### Description

This repository is a proof-of-concept to use the ‘Geek szitman supercamera’ camera-based products.
It features a small viewer app, which can also expose the camera as a standard webcam through
[v4l2loopback](https://github.com/v4l2loopback/v4l2loopback).

### Technical information

‘Geek szitman supercamera’ (2ce3:3828 or 0329:2022) is a camera chip (endoscope, glasses, ...) using the com.useeplus.protocol
(officially only working on iOS/Android devices with specific apps, such as ‘Usee Plus’).
Only firmware version 1.00 has been tested. USB descriptors can be found in file the `descriptors` folder.

**Contrary to the advertised specification**, the camera resolution is 640×480 (around 11 fps observed).

License is CC0: integrate this code as you like in other camera viewer software / apps.

If you have another hardware also using the ‘com.useeplus.protocol’ protocol, it may or may not work.
If it does, please open an issue so it can be added to the list of working devices.
If it does not work, please open an issue (see [Troubleshooting](#troubleshooting)).

### Build

Install dependencies (packages given assume a Debian-based system):

```bash
apt install build-essential libusb-1.0-0-dev libopencv-dev
```

Build the tool:

```bash
make
```

### Usage

Run the tool:

```bash
./out
```

It will display the camera feed in a GUI window.

- short press on the endoscope button will save the current frame in the `pics` folder
- long press on the endoscope button will switch between the two cameras
- press <kbd>q</kbd> or <kbd>Esc</kbd> in the GUI window to quit

Options:

```
./out [-o /dev/videoN] [--no-gui]
  -o, --output DEV  also write frames to a v4l2loopback device
  --no-gui          do not open a window (Ctrl-C to quit)
```

### Webcam output (v4l2loopback)

The camera does not use UVC, so it does not appear as a `/dev/video*` device on its own.
With `-o`, the tool decodes each JPEG frame and writes it as YUV420 to a v4l2loopback device,
so browsers, OBS, video-call apps, ffmpeg, etc. can use it like any webcam.

Install and load the module (`exclusive_caps=1` is needed for Chrome/Firefox/WebRTC to list the device):

```bash
apt install v4l2loopback-dkms
sudo modprobe v4l2loopback video_nr=10 card_label="Endoscope" exclusive_caps=1
```

Then run:

```bash
./out -o /dev/video10            # GUI window + webcam
./out -o /dev/video10 --no-gui   # webcam only
```

Check it with `ffplay -f v4l2 /dev/video10`.

To load the module automatically at boot:

```bash
echo v4l2loopback | sudo tee /etc/modules-load.d/v4l2loopback.conf
echo 'options v4l2loopback video_nr=10 card_label="Endoscope" exclusive_caps=1' | sudo tee /etc/modprobe.d/v4l2loopback.conf
```

### udev rules

To allow running the tool without superuser privileges, add a udev rule giving the `plugdev` group access
(avoid `MODE="0666"`, which lets every local user view the camera and send it raw USB commands):

```bash
echo 'SUBSYSTEMS=="usb", ENV{DEVTYPE}=="usb_device", ATTRS{idVendor}=="2ce3", ATTRS{idProduct}=="3828", MODE="0660", GROUP="plugdev"' | sudo tee /etc/udev/rules.d/70-supercamera.rules
echo 'SUBSYSTEMS=="usb", ENV{DEVTYPE}=="usb_device", ATTRS{idVendor}=="0329", ATTRS{idProduct}=="2022", MODE="0660", GROUP="plugdev"' | sudo tee -a /etc/udev/rules.d/70-supercamera.rules
sudo udevadm control --reload && sudo udevadm trigger
```

Make sure your user is in the group (`id -nG`; if not, `sudo usermod -aG plugdev $USER` and log in again).

### Troubleshooting

Feel free to open an issue.
Please recompile with `VERBOSE = 3` and include full logs.

If your hardware is different, do include its USB descriptors:

```bash
lsusb -vd $(lsusb | grep Geek | awk '{print $6}')
```

**Known issues:**

- `fatal: usb device not found`: check your device is properly plugged in. Check you have added udev rules properly. Try to run the program with root privileges: `sudo ./out`.
- `handle_upp_frame usb frame bad magic` once at startup: harmless, the packet is dropped and frames stream normally afterwards.
- `fatal: cannot open /dev/videoN` or `fatal: /dev/videoN is not a v4l2 output device`: the v4l2loopback module is not loaded, or `N` does not match its `video_nr`.

### License

This project is distributed under Creative Commons Zero v1.0 Universal (CC0-1.0).
