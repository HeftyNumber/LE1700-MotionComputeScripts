#!/bin/sh
# Tied to Square Button (F13) - Holds the ultimate modifier combo for 5 seconds
# Requires xdotool to be installed
xdotool keydown shift+ctrl+alt+super
sleep 5
xdotool keyup shift+ctrl+alt+super
