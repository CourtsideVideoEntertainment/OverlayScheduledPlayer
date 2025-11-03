# Device Info API - Quick Start Guide

## What Was Implemented

A complete system to fetch device information from the info-beamer API and display it on screen.

## Files Modified/Created

### Modified Files:
1. **`service`** - Added API polling functionality
   - **Automatically detects the current device** and fetches its data
   - Works on any info-beamer device without configuration
   - Sends data to Lua via node communication

2. **`node.lua`** - Added display rendering
   - Receives device data
   - Renders on-screen overlay with device information
   - Supports customization via API commands

### New Files:
1. **`DEVICE_INFO_API.md`** - Complete documentation
2. **`test_device_info.py`** - Test script demonstrating all features
3. **`device_info_control.py`** - Python helper module for easy control
4. **`DEVICE_INFO_QUICKSTART.md`** - This file

## Quick Test

### Method 1: Using the test script
```bash
./test_device_info.py
```

### Method 2: Using the control module
```python
from device_info_control import DeviceInfoController

controller = DeviceInfoController()
controller.enable()
controller.set_position('top-right', margin=30)
```

### Method 3: Direct commands
```python
import socket, json

sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
msg = "root/device_info/toggle:" + json.dumps({'enabled': True})
sock.sendto(msg.encode('utf8'), ('127.0.0.1', 4444))
```

## Displayed Information

The overlay shows (automatically for the current device):
- Device ID
- Device Serial Number
- Description
- Location  
- Current Run name
- Online Status
- Timezone

## Customization Options

### Position
- `top-left`, `top-right`, `bottom-left`, `bottom-right`
- Adjustable margin from edges

### Appearance
- Font size
- Text color (RGBA)
- Background color (RGBA)
- Padding

## Default Settings

- **Enabled**: Yes
- **Position**: Top-left corner
- **Margin**: 20 pixels
- **Font Size**: 30 pixels
- **Text Color**: White (1, 1, 1, 1)
- **Background**: Semi-transparent black (0, 0, 0, 0.7)
- **Update Interval**: 60 seconds

## Automatic Device Detection

✅ **No configuration needed!** The system automatically:
- Detects which device it's running on
- Fetches the correct device information
- Works the same on all devices
- Updates every 60 seconds

## Common Commands

```python
from device_info_control import DeviceInfoController
c = DeviceInfoController()

# Toggle
c.enable()
c.disable()

# Position
c.set_position('top-right', margin=30)

# Appearance  
c.set_appearance(
    font_size=40,
    text_color=[1, 1, 0, 1],  # Yellow
    bg_color=[0, 0, 0, 0.9]   # More opaque
)

# Reset
c.reset_defaults()
```

## Verify It's Working

1. Check service logs:
   ```bash
   tail -f info-beamer.log | grep "device info"
   ```

2. Enable display:
   ```bash
   ./device_info_control.py
   ```

3. Look for the info box in the top-left corner of your screen

## Troubleshooting

**Nothing displays?**
- Verify display is enabled: `controller.enable()`
- Check logs for API errors: `tail -f info-beamer.log | grep device`
- Ensure device is registered with info-beamer hosted

**API errors?**
- Check network connectivity
- Verify device is online in info-beamer dashboard
- Device will show fallback info (serial, etc.) if API unavailable

**Position wrong?**
- Try different positions: `controller.set_position('bottom-right')`
- Adjust margin: `controller.set_position('top-left', margin=50)`

## Next Steps

See `DEVICE_INFO_API.md` for complete documentation including:
- Detailed API reference
- Color format guide
- Integration examples
- Advanced troubleshooting

