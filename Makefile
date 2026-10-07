MAKEFLAGS += --no-builtin-rules --no-builtin-variables
.SUFFIXES:

BIN:=out
OPENCVFLAGS:=`pkg-config --cflags --libs opencv4`

all: $(BIN)

-include $(BIN).d

$(BIN): supercamera_poc.cpp Makefile
	g++ -std=c++23 "$<" -Wall -Wextra -O2 -MMD -g $(OPENCVFLAGS) -lusb-1.0 -o "$@"

clean:
	rm -rf $(BIN) $(BIN).d

PREFIX ?= /usr/local

install: $(BIN)
	install -Dm755 $(BIN) $(DESTDIR)$(PREFIX)/bin/supercamera
	install -Dm644 contrib/supercamera.service $(DESTDIR)/etc/systemd/system/supercamera.service
	install -Dm644 contrib/70-supercamera.rules $(DESTDIR)/etc/udev/rules.d/70-supercamera.rules
	install -Dm644 contrib/v4l2loopback-modules.conf $(DESTDIR)/etc/modules-load.d/v4l2loopback.conf
	install -Dm644 contrib/v4l2loopback-modprobe.conf $(DESTDIR)/etc/modprobe.d/v4l2loopback.conf
	[ -n "$(DESTDIR)" ] || { systemctl daemon-reload; udevadm control --reload; modprobe v4l2loopback; udevadm trigger --subsystem-match=usb --action=add; }

uninstall:
	-[ -n "$(DESTDIR)" ] || systemctl stop supercamera.service
	rm -f $(DESTDIR)$(PREFIX)/bin/supercamera \
	      $(DESTDIR)/etc/systemd/system/supercamera.service \
	      $(DESTDIR)/etc/udev/rules.d/70-supercamera.rules \
	      $(DESTDIR)/etc/modules-load.d/v4l2loopback.conf \
	      $(DESTDIR)/etc/modprobe.d/v4l2loopback.conf
	[ -n "$(DESTDIR)" ] || { systemctl daemon-reload; udevadm control --reload; }

.PHONY: all clean install uninstall
