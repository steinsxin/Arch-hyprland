#!/bin/bash

USER_DATA_DIR="$HOME/.config/kimi-browser"

# 首次运行创建目录
[ ! -d "$USER_DATA_DIR" ] && mkdir -p "$USER_DATA_DIR"

chromium \
    --app=https://kimi.com \
    --user-data-dir="$USER_DATA_DIR" \
    --enable-features=WebUIDarkMode \
    --force-dark-mode &
