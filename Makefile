APP_NAME := httpclient
BUILD_OUT := build/bin/$(APP_NAME).app
INSTALL_PATH := /Applications/$(APP_NAME).app

.PHONY: build dev install

build:
	wails build
	cp -r $(BUILD_OUT) $(INSTALL_PATH)

dev:
	wails dev

install:
	cp -r $(BUILD_OUT) $(INSTALL_PATH)
