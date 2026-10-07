# Geek szitman supercamera for Linux

Use cheap ‘Geek szitman supercamera’ USB endoscopes (and other cameras built on the same chip) on Linux,
without the vendor phone app.

- live viewer window
- **webcam output** through [v4l2loopback](https://github.com/v4l2loopback/v4l2loopback), so browsers, OBS,
  VLC, video-call apps and ffmpeg can use the camera like any other webcam
- snapshots from the camera's button
- headless mode for running as a background service

Based on [hbens/geek-szitman-supercamera](https://github.com/hbens/geek-szitman-supercamera), which
reverse-engineered the protocol.

## Supported hardware

| USB ID      | Status                                                    |
|-------------|-----------------------------------------------------------|
| `2ce3:3828` | tested (firmware 1.00): 640×480 JPEG, about 11 fps        |
| `0329:2022` | supported upstream                                        |

These cameras do not use the standard USB Video Class (UVC). They speak a vendor protocol
(`com.useeplus.protocol`, the one used by the ‘Usee Plus’ app), so on their own they never appear as `/dev/video*`.
Despite what the packaging may claim, the resolution is 640×480.

Other cameras using `com.useeplus.protocol` may work. Please open an issue either way
(see [Troubleshooting](#troubleshooting)). USB descriptors for the known devices are in [`descriptors/`](descriptors).

## Quick start

```bash
sudo apt install build-essential libusb-1.0-0-dev libopencv-dev
make
./out
```

If you get `fatal: usb device not found` or a permission error, set up the [udev rule](#permissions) first.

## Build

Dependencies (Debian/Ubuntu package names): `build-essential`, `libusb-1.0-0-dev`, `libopencv-dev`.

```bash
make
```

This produces the `out` binary.

## Permissions

To run without root, give the `plugdev` group access to the camera:

```bash
echo 'SUBSYSTEMS=="usb", ENV{DEVTYPE}=="usb_device", ATTRS{idVendor}=="2ce3", ATTRS{idProduct}=="3828", MODE="0660", GROUP="plugdev"' | sudo tee /etc/udev/rules.d/70-supercamera.rules
echo 'SUBSYSTEMS=="usb", ENV{DEVTYPE}=="usb_device", ATTRS{idVendor}=="0329", ATTRS{idProduct}=="2022", MODE="0660", GROUP="plugdev"' | sudo tee -a /etc/udev/rules.d/70-supercamera.rules
sudo udevadm control --reload && sudo udevadm trigger
```

Check that you are in the group with `id -nG`. If not, run `sudo usermod -aG plugdev $USER` and log in again.

Avoid `MODE="0666"`: it lets every local user watch the camera and send it raw USB commands.

## Usage

```
./out [-o /dev/videoN] [--no-gui]
  -o, --output DEV  also write frames to a v4l2loopback device
  --no-gui          do not open a window (Ctrl-C to quit)
```

With no options, `./out` shows the camera feed in a window.

- **short press** on the camera button: save the current frame to `pics/frame_<timestamp>.jpg`
- **long press** on the camera button: switch between cameras, on models that have two
- <kbd>q</kbd> or <kbd>Esc</kbd> in the window: quit

## Webcam output (v4l2loopback)

With `-o`, each frame is decoded and written as YUV420 to a v4l2loopback device, which other programs read like
a normal webcam.

1. Load the module. `exclusive_caps=1` is needed for Chrome, Firefox and other WebRTC apps to list the device.

   ```bash
   sudo apt install v4l2loopback-dkms
   sudo modprobe v4l2loopback video_nr=10 card_label="Endoscope" exclusive_caps=1
   ```

2. Start streaming:

   ```bash
   ./out -o /dev/video10            # window + webcam
   ./out -o /dev/video10 --no-gui   # webcam only
   ```

3. Open "Endoscope" in any camera app, or test with `ffplay -f v4l2 /dev/video10` or `vlc v4l2:///dev/video10`.

To load the module automatically at boot:

```bash
echo v4l2loopback | sudo tee /etc/modules-load.d/v4l2loopback.conf
echo 'options v4l2loopback video_nr=10 card_label="Endoscope" exclusive_caps=1' | sudo tee /etc/modprobe.d/v4l2loopback.conf
```

## Protocol notes

All values are little-endian.

- **Setup:** claim interfaces 0 and 1, and select alternate setting 1 on interface 1.
- **Start:** send `FF 55 FF 55 EE 10` to bulk endpoint `0x02`, then `BB AA 05 00 00` to bulk endpoint `0x01`.
- **Video:** read 1024-byte bulk transfers from endpoint `0x81`. Each transfer begins with:
  - a 5-byte USB header: magic `0xBBAA`, camera id (7 or 11), 16-bit payload length
  - a 7-byte camera header: frame id, camera number, flags (bit 0: g-sensor data present,
    bit 1: button pressed), 32-bit g-sensor value
  - JPEG data
- **Frames:** consecutive transfers with the same frame id are concatenated into one JPEG.

## Troubleshooting

When opening an issue, recompile with `VERBOSE = 3` in `supercamera_poc.cpp` and include the full log. If your
hardware is not in the table above, include its descriptors (replace the ID with yours):

```bash
lsusb -v -d 2ce3:3828
```

| Message | Meaning |
|---------|---------|
| `fatal: usb device not found` | Camera not plugged in, or no permission: see [Permissions](#permissions). `sudo ./out` confirms whether it is a permission problem. |
| `usb frame bad magic`, once at startup | Harmless: the partial packet is dropped and frames stream normally afterwards. |
| `fatal: cannot open /dev/videoN` or `... is not a v4l2 output device` | The v4l2loopback module is not loaded, or `N` does not match its `video_nr`. |
| `cam frame too small` or `picture too large, dropped` | Malformed data from the camera, which is ignored. If it happens constantly, please open an issue. |

## Credits

Protocol and original viewer by [hbens](https://github.com/hbens/geek-szitman-supercamera), with thanks to
doctormo, jmz3 and RGBA-CRT.

## License

[CC0 1.0 Universal](https://creativecommons.org/publicdomain/zero/1.0/): public domain. Use this code however
you like.
