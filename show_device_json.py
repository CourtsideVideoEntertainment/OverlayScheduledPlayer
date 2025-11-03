#!/usr/bin/env python3
"""
Show device information as full-page JSON display.

Usage:
  ./show_device_json.py on    - Show device info page
  ./show_device_json.py off   - Return to normal display
  ./show_device_json.py       - Toggle device info page
"""

import socket
import sys

def send_command(data):
    sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    message = "root/device_info/page:%s" % data
    sock.sendto(message.encode('utf8'), ('127.0.0.1', 4444))
    return True

if __name__ == '__main__':
    if len(sys.argv) > 1:
        action = sys.argv[1].lower()
        if action in ['on', 'off']:
            send_command(action)
            print("Device info page: %s" % action)
        else:
            print("Invalid argument. Use 'on' or 'off'")
            sys.exit(1)
    else:
        # Toggle
        send_command("toggle")
        print("Device info page toggled")

