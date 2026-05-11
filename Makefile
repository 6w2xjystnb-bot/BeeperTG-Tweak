THEOS_DEVICE_IP = 192.168.1.100
ARCHS = arm64 arm64e
TARGET = iphone:clang:latest:15.0

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = BeeperTG

BeeperTG_FILES = src/Tweak.m src/BPVKBridge.m src/BPVKChatsController.m
BeeperTG_CFLAGS = -fobjc-arc -Wno-deprecated-declarations
BeeperTG_FRAMEWORKS = UIKit Foundation
BeeperTG_LIBRARIES =

include $(THEOS_MAKE_PATH)/tweak.mk
