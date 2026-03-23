#!/bin/bash

# 启动 OpenCode
kitty -e opencode &

# 等待窗口出现
sleep 0.3

# 获取显示器分辨率
MONITOR_INFO=$(hyprctl monitors -j | jq -r '.[0]')
MONITOR_WIDTH=$(echo $MONITOR_INFO | jq -r '.width')
MONITOR_HEIGHT=$(echo $MONITOR_INFO | jq -r '.height')

# 计算大小
WIDTH=$((MONITOR_WIDTH * 30 / 100))
HEIGHT=$((MONITOR_HEIGHT * 40 / 100))

# 设置浮动、大小和居中
hyprctl dispatch togglefloating
hyprctl dispatch resizewindowpixel exact $WIDTH $HEIGHT, active
hyprctl dispatch centerwindow
