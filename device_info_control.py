#!/usr/bin/env python
"""
Device Info Display Control Module

A simple helper module to control the device info display.
"""

import socket
import json

class DeviceInfoController:
    """Controller for the device info display overlay"""
    
    def __init__(self, host='127.0.0.1', port=4444):
        self.host = host
        self.port = port
    
    def _send_command(self, path, data):
        """Send a command to the info-beamer node"""
        sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        message = "root%s:%s" % (path, json.dumps(data))
        sock.sendto(message.encode('utf8'), (self.host, self.port))
        return True
    
    def enable(self):
        """Enable the device info display"""
        return self._send_command('/device_info/toggle', {'enabled': True})
    
    def disable(self):
        """Disable the device info display"""
        return self._send_command('/device_info/toggle', {'enabled': False})
    
    def set_position(self, position='top-left', margin=20):
        """
        Set the position of the device info display.
        
        Args:
            position (str): One of 'top-left', 'top-right', 'bottom-left', 'bottom-right'
            margin (int): Distance from screen edge in pixels
        """
        valid_positions = ['top-left', 'top-right', 'bottom-left', 'bottom-right']
        if position not in valid_positions:
            raise ValueError("Position must be one of: %s" % ', '.join(valid_positions))
        
        return self._send_command('/device_info/position', {
            'position': position,
            'margin': margin
        })
    
    def set_appearance(self, font_size=30, padding=15, text_color=None, bg_color=None):
        """
        Set the appearance of the device info display.
        
        Args:
            font_size (int): Font size in pixels
            padding (int): Padding inside the box in pixels
            text_color (list): RGBA color as [R, G, B, A] with values 0.0-1.0
            bg_color (list): RGBA color for background
        """
        data = {
            'font_size': font_size,
            'padding': padding
        }
        
        if text_color is not None:
            if len(text_color) != 4:
                raise ValueError("text_color must be [R, G, B, A]")
            data['text_color'] = text_color
        
        if bg_color is not None:
            if len(bg_color) != 4:
                raise ValueError("bg_color must be [R, G, B, A]")
            data['bg_color'] = bg_color
        
        return self._send_command('/device_info/appearance', data)
    
    def reset_defaults(self):
        """Reset to default appearance and position"""
        self.set_position('top-left', 20)
        self.set_appearance(
            font_size=30,
            padding=15,
            text_color=[1, 1, 1, 1],  # White
            bg_color=[0, 0, 0, 0.7]   # Semi-transparent black
        )
        return True


# Example usage
if __name__ == '__main__':
    import time
    
    controller = DeviceInfoController()
    
    print("Device Info Controller Demo")
    print("============================\n")
    
    # Enable display
    print("Enabling display...")
    controller.enable()
    time.sleep(2)
    
    # Move to different positions
    for position in ['top-right', 'bottom-right', 'bottom-left', 'top-left']:
        print("Moving to %s..." % position)
        controller.set_position(position, margin=30)
        time.sleep(2)
    
    # Change colors
    print("Changing to yellow text...")
    controller.set_appearance(
        font_size=35,
        text_color=[1, 1, 0, 1],  # Yellow
        bg_color=[0, 0, 0, 0.85]
    )
    time.sleep(3)
    
    # Reset to defaults
    print("Resetting to defaults...")
    controller.reset_defaults()
    time.sleep(2)
    
    # Disable
    print("Disabling display...")
    controller.disable()
    
    print("Demo complete!")

