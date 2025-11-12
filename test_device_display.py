#!/usr/bin/env python3
"""
Test script to immediately send device data and trigger display.
This bypasses the 60-second wait to test the display immediately.
"""

import socket
import json

# Sample device data matching the API response structure
device_data = {
    "description": "Screen_1WestNew",
    "device_data": {},
    "geo": {
        "lat": 47.5579,
        "lon": -122.1633,
        "source": "ip"
    },
    "hw": {
        "cores": 4,
        "features": ["h264", "hevc", "image2k", "image4k"],
        "memory": 8192,
        "model": "Pi 5B",
        "platform": "pi-5",
        "type": "pi"
    },
    "id": 43493,
    "is_online": True,
    "is_suspended": False,
    "is_synced": True,
    "last_seen_ago": 23,
    "location": "Unknown location",
    "maintenance": [],
    "offline": {
        "chargeable": 2,
        "licensed": False,
        "max_offline": 7,
        "offline_sync": False,
        "plan": "online"
    },
    "reboot": 0,
    "run": {
        "channel": "stable",
        "features": ["push-sync", "sync-file-v2"],
        "pi_revision": "d04171",
        "public_addr": "73.42.175.217",
        "resolution": "1920x1080",
        "restarted": 1762746308,
        "tag": "stable-0014",
        "version": "241217-d34b18"
    },
    "schedule": None,
    "serial": "3436955696",
    "setup": {
        "id": 260686,
        "name": "Debug_Livestream",
        "updated": 1759369362
    },
    "status": "Idle",
    "timezone": "America/Los_Angeles",
    "upgrade": {
        "blocked": 0
    },
    "userdata": {}
}

def send_device_data():
    """Send device data to Lua"""
    sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    message = 'root/device_info:' + json.dumps(device_data)
    sock.sendto(message.encode('utf8'), ('127.0.0.1', 4444))
    print("Device data sent (%d bytes)" % len(message))

def show_page():
    """Show the device info page"""
    sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    sock.sendto(b'root/device_info/page/on:', ('127.0.0.1', 4444))
    print("Page display enabled")

if __name__ == '__main__':
    print("Testing device info display...")
    print("1. Sending device data...")
    send_device_data()
    print("2. Enabling page display...")
    show_page()
    print("\nDone! Check your screen.")
    print("To turn off: curl -X POST https://info-beamer.com/api/v1/device/43493/node/root/device_info/page/off -H 'Authorization: Bearer YOUR_KEY'")

