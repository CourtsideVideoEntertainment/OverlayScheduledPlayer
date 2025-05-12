#!/usr/bin/env lua
-- test_qr_scaling.lua
-- This script tests the QR code scaling functionality

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
            draw = function() print("Drawing colored texture") end
        }
    end,
    load_font = function()
        return {
            width = function() return 100 end,
            write = function() print("Writing text") end
        }
    end
}

-- Mock GL functions
gl = {
    clear = function() end,
    translate = function() end,
    pushMatrix = function() end,
    popMatrix = function() end
}

print("===== QR CODE SCALING TEST =====")
print("Loading modules...")

-- Load the QR code overlay module
local ok, qrcode_overlay = pcall(function() return require "qrcode_overlay" end)
if not ok then
    print("Error loading qrcode_overlay module:", qrcode_overlay)
    os.exit(1)
end
print("QR code overlay module loaded successfully")

-- Function to send JSON-like data to the data mapper
function send_to_data_mapper(channel, data)
    print("\nSending data to channel: " .. channel)
    print("Data: " .. data)
    
    if channel == "qr/appearance" then
        -- Parse module_size from data
        local module_size = data:match('"module_size":(%d+)')
        if module_size then
            print("Setting module_size to " .. module_size)
            qrcode_overlay.update_appearance({module_size = tonumber(module_size)})
        end
        
        -- Parse border_size from data
        local border_size = data:match('"border_size":(%d+)')
        if border_size then
            print("Setting border_size to " .. border_size)
            qrcode_overlay.update_appearance({border_size = tonumber(border_size)})
        end
    end
end

-- Function to trigger QR code generation and display dimensions
function test_qr_scaling(target_width, target_height, position_x, position_y)
    print("\n----- Testing QR code with target dimensions: " .. target_width .. "x" .. target_height .. " -----")
    
    -- Generate the QR code with specified dimensions
    print("\nGenerating QR code...")
    local result = qrcode_overlay.handle_remote_trigger("3", target_width, target_height)
    print("Remote trigger result:", result)
    
    -- Draw the QR code at the specified position
    print("\nDrawing QR code at position: " .. position_x .. "," .. position_y)
    local drawn = qrcode_overlay.draw_qr(position_x, position_y)
    print("QR code drawn:", drawn)
    
    -- Get and display the QR code dimensions
    local dims = qrcode_overlay.get_dimensions()
    print("\n--- QR CODE DIMENSIONS SUMMARY ---")
    print("Matrix size: " .. dims.matrix_size.width .. "x" .. dims.matrix_size.height .. " modules")
    print("Module size: " .. dims.module_size .. " pixels")
    print("Target dimensions: " .. target_width .. "x" .. target_height .. " pixels")
    print("Actual QR size: " .. dims.pixel_size.width .. "x" .. dims.pixel_size.height .. " pixels")
    print("Border size: " .. dims.border_size .. " pixels")
    print("Title height: " .. dims.title_height .. " pixels")
    print("Total rendered size: " .. dims.total_size.width .. "x" .. dims.total_size.height .. " pixels")
    if dims.use_scaling then
        print("Scaling: enabled, factor = " .. dims.scale_factor)
    else
        print("Scaling: disabled")
    end
    print("Position: (" .. dims.last_position.x .. "," .. dims.last_position.y .. ")")
    print("--------------------------------")
    
    return dims
end

-- Test with different target dimensions
local position_x = 200
local position_y = 200

-- Test with small dimensions (matches what you saw in the debug output)
local small_dims = test_qr_scaling(25, 25, position_x, position_y)

-- Test with medium dimensions
local medium_dims = test_qr_scaling(100, 100, position_x, position_y)

-- Test with large dimensions
local large_dims = test_qr_scaling(300, 300, position_x, position_y)

-- Compare the dimensions
print("\n===== DIMENSION COMPARISON =====")
print("Small QR Code (25x25): Actual size = " .. small_dims.pixel_size.width .. "x" .. small_dims.pixel_size.height .. 
      " pixels, Module size = " .. small_dims.module_size .. " pixels")
print("Medium QR Code (100x100): Actual size = " .. medium_dims.pixel_size.width .. "x" .. medium_dims.pixel_size.height .. 
      " pixels, Module size = " .. medium_dims.module_size .. " pixels")
print("Large QR Code (300x300): Actual size = " .. large_dims.pixel_size.width .. "x" .. large_dims.pixel_size.height .. 
      " pixels, Module size = " .. large_dims.module_size .. " pixels")
print("================================")

print("\nQR code scaling test completed!") 