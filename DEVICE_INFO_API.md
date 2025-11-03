# Device Info API Display

This feature fetches device information from the info-beamer API and displays it on screen.

## Overview

The system consists of two main components:

1. **Python Service (`service`)**: Fetches device details from the info-beamer API every 60 seconds
2. **Lua Display (`node.lua`)**: Renders the device information on screen with customizable appearance

## Features

- Automatic API polling every 60 seconds
- Customizable position (top-left, top-right, bottom-left, bottom-right)
- Adjustable appearance (font size, colors, padding, margins)
- Toggle display on/off
- Semi-transparent background for readability

## Displayed Information

The following device details are shown:

- Device ID
- Device Serial Number
- Description
- Location
- Current Run/Setup name
- Online Status
- Timezone

## API Endpoint

The service **automatically detects the current device** and fetches its information from the info-beamer API. No manual configuration needed!

The system uses the device's metadata to determine the correct API endpoint. This means:
- ✅ Works on any info-beamer device
- ✅ No hardcoded device IDs
- ✅ Automatically shows the correct device info
- ✅ Deploy the same package to multiple devices

## Control Commands

### Toggle Display

Enable or disable the device info display:

```python
import socket, json

def send_cmd(path, data):
    sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    message = "root%s:%s" % (path, json.dumps(data))
    sock.sendto(message.encode('utf8'), ('127.0.0.1', 4444))

# Enable
send_cmd('/device_info/toggle', {'enabled': True})

# Disable
send_cmd('/device_info/toggle', {'enabled': False})
```

### Change Position

Move the info box to different corners of the screen:

```python
# Top-left
send_cmd('/device_info/position', {
    'position': 'top-left',
    'margin': 20
})

# Top-right
send_cmd('/device_info/position', {
    'position': 'top-right',
    'margin': 20
})

# Bottom-left
send_cmd('/device_info/position', {
    'position': 'bottom-left',
    'margin': 20
})

# Bottom-right
send_cmd('/device_info/position', {
    'position': 'bottom-right',
    'margin': 20
})
```

### Change Appearance

Customize the look of the device info display:

```python
send_cmd('/device_info/appearance', {
    'font_size': 30,           # Font size in pixels
    'padding': 15,             # Padding inside the box
    'text_color': [1, 1, 1, 1],  # RGBA: white text
    'bg_color': [0, 0, 0, 0.7]   # RGBA: semi-transparent black background
})

# Example: Yellow text with more opaque background
send_cmd('/device_info/appearance', {
    'font_size': 40,
    'padding': 20,
    'text_color': [1, 1, 0, 1],  # Yellow
    'bg_color': [0, 0, 0, 0.9]   # More opaque
})
```

### Color Format

Colors use RGBA format with values from 0.0 to 1.0:
- `[R, G, B, A]`
- Red: `[1, 0, 0, 1]`
- Green: `[0, 1, 0, 1]`
- Blue: `[0, 0, 1, 1]`
- White: `[1, 1, 1, 1]`
- Black: `[0, 0, 0, 1]`
- Semi-transparent Black: `[0, 0, 0, 0.7]`

## Testing

A test script is provided to demonstrate all features:

```bash
./test_device_info.py
```

This script will:
1. Enable the device info display
2. Move it to different positions
3. Change the appearance
4. Reset to defaults
5. Disable the display

## Default Configuration

```lua
device_info_display = {
    enabled = true,
    position = "top-left",
    margin = 20,
    font_size = 30,
    text_color = {1, 1, 1, 1},  -- white
    bg_color = {0, 0, 0, 0.7},  -- semi-transparent black
    padding = 15
}
```

## Integration

The device info is rendered on top of your regular content but below debug overlays. It updates automatically every 60 seconds with fresh data from the API.

## Troubleshooting

### Display not showing?

1. Check if the display is enabled:
   ```python
   send_cmd('/device_info/toggle', {'enabled': True})
   ```

2. Check the service logs:
   ```bash
   tail -f info-beamer.log | grep "device info"
   ```

3. Verify the API endpoint is correct in the `service` file

### API errors?

- Ensure the device ID is correct
- Check network connectivity
- Verify API authentication if required
- Check the service logs for error messages

### Display positioned incorrectly?

Try adjusting the margin:
```python
send_cmd('/device_info/position', {
    'position': 'top-left',
    'margin': 50  # Increase for more spacing from edges
})
```

## Notes

- The API is polled every 60 seconds to avoid rate limiting
- Network errors are logged but don't crash the service
- The display automatically handles missing or null values
- Font rendering uses the default font included with the package

