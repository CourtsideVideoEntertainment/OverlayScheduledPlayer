#!/bin/bash
# startup_test.sh - Test script to verify remote trigger functionality

echo "==============================="
echo " Remote Trigger Test Script   "
echo "==============================="

# Give info-beamer time to start up
echo "Waiting for info-beamer to start up..."
sleep 5

# Send trigger 4 (regular page) first
echo "Sending trigger 4 (regular page)..."
echo -n "4" > /dev/null | nc -U -w 1 "$HOME/Documents/courtside/infobeamer_testpackages/package-scheduled-player/node.sock" 2>/dev/null || \
  echo -n "4" > /dev/null | socat - UNIX-CONNECT:"$HOME/Documents/courtside/infobeamer_testpackages/package-scheduled-player/node.sock" 2>/dev/null || \
  echo "Failed to send trigger 4. Is info-beamer running with the correct socket path?"

sleep 5

# Then send trigger 3 (QR code page)
echo "Sending trigger 3 (QR code page)..."
echo -n "3" > /dev/null | nc -U -w 1 "$HOME/Documents/courtside/infobeamer_testpackages/package-scheduled-player/node.sock" 2>/dev/null || \
  echo -n "3" > /dev/null | socat - UNIX-CONNECT:"$HOME/Documents/courtside/infobeamer_testpackages/package-scheduled-player/node.sock" 2>/dev/null || \
  echo "Failed to send trigger 3. Is info-beamer running with the correct socket path?"

echo "Test complete. Check info-beamer output for results." 