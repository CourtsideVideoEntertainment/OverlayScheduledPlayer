#!/usr/bin/env lua
-- test_qr_show.lua
-- This script manually tests QR code display by simulating trigger events

print("===== QR CODE DISPLAY TEST =====")

-- Initialize NATIVE_WIDTH and NATIVE_HEIGHT as globals for testing
NATIVE_WIDTH = 1920
NATIVE_HEIGHT = 1080

-- Mock sys table for testing
sys = {
    now = function() return os.time() end
}

-- Mock resource table for testing
resource = {
    create_colored_texture = function() 
        return {
            draw = function(self, x1, y1, x2, y2, alpha) 
                print(string.format("Drawing colored texture at (%.1f,%.1f) to (%.1f,%.1f) with alpha %.2f", 
                    x1, y1, x2, y2, alpha or 1.0))
            end
        }
    end,
    load_font = function()
        return {
            width = function(self, text, size) return size * string.len(text) * 0.6 end,
            write = function(self, x, y, text, size) 
                print(string.format("Writing text '%s' at (%.1f,%.1f) with size %.1f", text, x, y, size))
            end
        }
    end,
    load_image = function()
        return {
            draw = function(self, x1, y1, x2, y2)
                print(string.format("Drawing image at (%.1f,%.1f) to (%.1f,%.1f)", x1, y1, x2, y2))
            end
        }
    end,
    open_file = function(filename)
        print("Opening file: " .. filename)
        return filename
    end
}

-- Mock GL functions
gl = {
    clear = function() end,
    translate = function() end,
    pushMatrix = function() end,
    popMatrix = function() end,
    rotate = function() end
}

-- Define QR_POSITION_CONFIG
QR_POSITION_CONFIG = {
    position = "bottom-right",
    width = 150,
    height = 150,
    margin = 20,
    custom_x = 100,
    custom_y = 100
}

-- Load the QR overlay module
print("Loading QR code module...")
local qrcode_overlay = require "qrcode_overlay"
print("QR code module loaded successfully")

-- Print the current QR code status
print("\nInitial QR code status:")
local status = qrcode_overlay.get_status()
print("Visible:", status.visible)
print("Permanent:", status.permanent)
print("Current trigger:", status.current_trigger)
print("Has draw function:", status.has_draw_function)

-- Test triggering QR code display
print("\nTesting QR code trigger (3)...")
local result = qrcode_overlay.handle_remote_trigger("3", QR_POSITION_CONFIG.width, QR_POSITION_CONFIG.height)
print("Trigger result:", result)

-- Get updated status
print("\nUpdated QR code status:")
status = qrcode_overlay.get_status()
print("Visible:", status.visible)
print("Permanent:", status.permanent)
print("Current trigger:", status.current_trigger)
print("Has draw function:", status.has_draw_function)

-- Calculate QR code position based on configuration
local qr_position = QR_POSITION_CONFIG.position
local qr_width = QR_POSITION_CONFIG.width
local qr_height = QR_POSITION_CONFIG.height
local margin = QR_POSITION_CONFIG.margin
local custom_x = QR_POSITION_CONFIG.custom_x
local custom_y = QR_POSITION_CONFIG.custom_y

-- Calculate position based on selected corner
local qr_x, qr_y
if qr_position == "top-left" then
    qr_x = margin
    qr_y = margin
elseif qr_position == "top-right" then
    qr_x = NATIVE_WIDTH - qr_width - margin
    qr_y = margin
elseif qr_position == "bottom-left" then
    qr_x = margin
    qr_y = NATIVE_HEIGHT - qr_height - margin
elseif qr_position == "bottom-right" then
    qr_x = NATIVE_WIDTH - qr_width - margin
    qr_y = NATIVE_HEIGHT - qr_height - margin
elseif qr_position == "custom" then
    qr_x = custom_x
    qr_y = custom_y
else
    -- Default to top-left if invalid position
    qr_x = margin
    qr_y = margin
end

-- Try to draw the QR code
print("\nTesting QR code drawing at position:", qr_x, qr_y)
local drawn = qrcode_overlay.draw_qr(qr_x, qr_y)
print("QR code drawn:", drawn)

-- Get dimensions for debugging
local dims = qrcode_overlay.get_dimensions()
print("\n--- QR CODE DIMENSIONS SUMMARY ---")
print("Matrix size:", dims.matrix_size.width .. "x" .. dims.matrix_size.height, "modules")
print("Module size:", dims.module_size, "pixels")
print("Actual QR size:", dims.pixel_size.width .. "x" .. dims.pixel_size.height, "pixels")
print("Border size:", dims.border_size, "pixels")
print("Title height:", dims.title_height, "pixels")
print("Total rendered size:", dims.total_size.width .. "x" .. dims.total_size.height, "pixels")
print("Position:", "(" .. dims.last_position.x .. "," .. dims.last_position.y .. ")")
print("--------------------------------")

print("\nTesting hiding the QR code...")
local hide_result = qrcode_overlay.handle_remote_trigger("1")
print("Hide result:", hide_result)

-- Check if QR code is hidden
print("\nAfter hiding:")
status = qrcode_overlay.get_status()
print("Visible:", status.visible)
print("Current trigger:", status.current_trigger)

print("\nTesting drawing after hiding:")
drawn = qrcode_overlay.draw_qr(qr_x, qr_y)
print("QR code drawn:", drawn, "(should be false)")

print("\nQR code display test completed!") 