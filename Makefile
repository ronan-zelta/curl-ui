APP_NAME := httpclient
BUILD_OUT := build/bin/$(APP_NAME).app
INSTALL_PATH := /Applications/$(APP_NAME).app

.PHONY: build dev install run

build:
	wails build
	rm -rf $(INSTALL_PATH) && cp -r $(BUILD_OUT) $(INSTALL_PATH)

dev:
	wails dev

run:
	wails build
	rm -rf $(INSTALL_PATH) && cp -r $(BUILD_OUT) $(INSTALL_PATH)
	pkill -x $(APP_NAME) 2>/dev/null || true
	sleep 1
	open $(INSTALL_PATH)

install:
	rm -rf $(INSTALL_PATH) && cp -r $(BUILD_OUT) $(INSTALL_PATH)
