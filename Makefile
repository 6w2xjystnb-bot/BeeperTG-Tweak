THEOS_DEVICE_IP = 192.168.1.100
ARCHS = arm64 arm64e
TARGET = iphone:clang:latest:15.0

include $(THEOS)/makefiles/common.mk

LIBRARY_NAME = BeeperTG

BeeperTG_FILES = $(wildcard src/*.m)
BeeperTG_CFLAGS = -fobjc-arc -Wno-deprecated-declarations
BeeperTG_PRIVATE_FRAMEWORKS = UIKit
BeeperTG_EXTRA_FRAMEWORKS =
BeeperTG_LIBRARIES =

include $(THEOS_MAKE_PATH)/library.mk

after-install::
	install.exec "killall -9 Telegram"
