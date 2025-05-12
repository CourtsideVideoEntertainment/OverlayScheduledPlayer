# QR Code Exact Sizing Feature

This document explains how to use the QR code exact sizing feature that allows you to specify the precise dimensions of QR codes displayed on screen.

## Overview

The QR code system has been enhanced to support exact sizing of QR codes. Previously, the QR code size was determined solely by the module size multiplied by the matrix dimensions, which could result in QR codes that didn't match the desired dimensions.

With the new scaling feature, you can specify the exact width and height of the QR code in pixels, and the system will automatically adjust the rendering to match those dimensions.

## How to Use Exact Sizing

To create a QR code with exact dimensions:

1. **Set the position and size** using the `qr/position` channel:
   ```json
   {
     "position": "custom", // or "bottom-right", "top-left", etc.
     "width": 200,         // Exact width in pixels
     "height": 200,        // Exact height in pixels
     "custom_x": 400,      // Only needed for "custom" position
     "custom_y": 300       // Only needed for "custom" position
   }
   ```

2. **Set the appearance** using the `qr/appearance` channel:
   ```json
   {
     "module_size": 5,          // Will be automatically adjusted as needed
     "border_size": 10,         // Border size in pixels
     "title_text": "Scan Me!",  // Optional title text
     "title_height": 30,        // Title height in pixels
     "title_font_size": 20,     // Font size for title
     "title_color": "#FFFFFF",  // Title text color
     "background_color": "#000000", // QR code background color
     "foreground_color": "#FFFFFF"  // QR code foreground color
   }
   ```

3. **Trigger the QR code display** using the `remote/trigger` channel:
   ```json
   {
     "action": "show_qr",
     "trigger": "1"  // Identifier for this QR code (can be any string)
   }
   ```

## How Scaling Works

When the `width` and `height` parameters are specified in the `qr/position` channel, the system will:

1. Generate the QR code matrix based on the content to be encoded
2. Calculate the appropriate module size to achieve the specified dimensions
3. Render the QR code at exactly the requested size

The total rendered size of the QR code (including border and title) will be slightly larger than the specified dimensions to accommodate the border and title areas.

## Example Configurations

### Small QR Code (100x100 pixels)
```json
// Position
{
  "position": "bottom-right",
  "width": 100,
  "height": 100,
  "margin": 20
}

// Appearance
{
  "module_size": 3,
  "border_size": 5,
  "title_text": "",
  "title_height": 0
}
```

### Medium QR Code (200x200 pixels)
```json
// Position
{
  "position": "custom",
  "width": 200,
  "height": 200,
  "custom_x": 400,
  "custom_y": 300
}

// Appearance
{
  "module_size": 5,
  "border_size": 10,
  "title_text": "Scan Me!",
  "title_height": 30,
  "title_font_size": 20
}
```

### Large QR Code (300x300 pixels)
```json
// Position
{
  "position": "top-left",
  "width": 300,
  "height": 300,
  "margin": 30
}

// Appearance
{
  "module_size": 7,
  "border_size": 15,
  "title_text": "Scan for more info",
  "title_height": 40,
  "title_font_size": 24,
  "title_color": "#FFD700",
  "background_color": "#0000AA",
  "foreground_color": "#00FF00"
}
```

## Best Practices

1. **QR Code Size**: Ensure your QR codes are large enough to be scanned easily. A good minimum size is around 100x100 pixels for most phone cameras.

2. **Content Length**: Longer URLs or content will create more complex QR codes with smaller individual modules. Consider using URL shorteners for long URLs.

3. **Appearance**: Maintain good contrast between foreground and background colors for optimal scanning.

4. **Positioning**: When using `custom` position, ensure the QR code fits entirely within the screen boundaries.

5. **Module Size**: While the system will automatically adjust the module size to achieve the requested dimensions, specifying a sensible starting value can help the system produce better results.

## Testing

You can test the QR code sizing feature using the included test scripts:

- `test_qr_scaling.lua`: Tests various dimensions and displays detailed sizing information
- `test_qr_exact_size.lua`: Demonstrates how to use the exact sizing feature with various configurations

Run these scripts from the command line with:
```
lua test_qr_scaling.lua
lua test_qr_exact_size.lua
```

## Troubleshooting

If the QR code is not displaying at the expected size:

1. Verify that you're specifying both `width` and `height` in the `qr/position` channel
2. Check if there are any error messages in the console logs
3. Run the `test_qr_scaling.lua` script to see detailed dimension information
4. Ensure the QR code is not being clipped by screen boundaries 