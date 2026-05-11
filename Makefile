THEOS_DEVICE_IP = 192.168.1.100
ARCHS = arm64 arm64e
TARGET = iphone:clang:latest:15.0

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = BeeperTG

BeeperTG_FILES = $(wildcard src/*.xm src/*.m src/*.mm)
BeeperTG_CFLAGS = -fobjc-arc -Wno-deprecated-declarations
BeeperTG_PRIVATE_FRAMEWORKS = UIKit
BeeperTG_EXTRA_FRAMEWORKS = 
BeeperTG_LIBRARIES = substrate

include $(THEOS_MAKE_PATH)/tweak.mk

after-install::
	install.exec "killall -9 Telegram"
