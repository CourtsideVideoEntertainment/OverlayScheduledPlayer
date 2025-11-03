#!/usr/bin/env python
"""
Test script to demonstrate device info display control.

This script shows how to control the device info display using
the info-beamer node communication system.
"""

import socket
import json
import time

def send_to_node(path, data):
    """Send data to the info-beamer node via UDP"""
    sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    message = "root%s:%s" % (path, json.dumps(data))
    sock.sendto(message.encode('utf8'), ('127.0.0.1', 4444))
    print("Sent: %s" % message)

def main():
    print("Device Info Display Test Script")
    print("================================\n")
    
    # Test 1: Toggle display on
    print("Test 1: Enabling device info display")
    send_to_node('/device_info/toggle', {'enabled': True})
    time.sleep(2)
    
    # Test 2: Change position to top-right
    print("\nTest 2: Moving to top-right")
    send_to_node('/device_info/position', {
        'position': 'top-right',
        'margin': 30
    })
    time.sleep(3)
    
    # Test 3: Change position to bottom-left
    print("\nTest 3: Moving to bottom-left")
    send_to_node('/device_info/position', {
        'position': 'bottom-left',
        'margin': 20
    })
    time.sleep(3)
    
    # Test 4: Change appearance (larger text)
    print("\nTest 4: Changing appearance (larger text)")
    send_to_node('/device_info/appearance', {
        'font_size': 40,
        'padding': 20,
        'text_color': [1, 1, 0, 1],  # Yellow text
        'bg_color': [0, 0, 0, 0.9]   # More opaque background
    })
    time.sleep(3)
    
    # Test 5: Reset to defaults
    print("\nTest 5: Resetting to defaults")
    send_to_node('/device_info/appearance', {
        'font_size': 30,
        'padding': 15,
        'text_color': [1, 1, 1, 1],  # White text
        'bg_color': [0, 0, 0, 0.7]   # Semi-transparent black
    })
    send_to_node('/device_info/position', {
        'position': 'top-left',
        'margin': 20
    })
    time.sleep(2)
    
    # Test 6: Toggle display off
    print("\nTest 6: Disabling device info display")
    send_to_node('/device_info/toggle', {'enabled': False})
    
    print("\nTests completed!")

if __name__ == '__main__':
    main()

