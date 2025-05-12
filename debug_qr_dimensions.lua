#!/usr/bin/env lua
-- debug_qr_dimensions.lua
-- This script tests QR code dimensions by triggering the QR code with different size settings

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

print("===== QR CODE DIMENSION DEBUGGER =====")
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
function test_qr_dimensions(module_size, position_x, position_y)
    print("\n----- Testing QR code with module_size: " .. module_size .. " -----")
    
    -- Set the module size
    send_to_data_mapper("qr/appearance", '{"module_size":' .. module_size .. '}')
    
    -- Generate the QR code
    print("\nGenerating QR code...")
    local result = qrcode_overlay.handle_remote_trigger("3")
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
    print("QR code size: " .. dims.pixel_size.width .. "x" .. dims.pixel_size.height .. " pixels")
    print("Border size: " .. dims.border_size .. " pixels")
    print("Title height: " .. dims.title_height .. " pixels")
    print("Total rendered size: " .. dims.total_size.width .. "x" .. dims.total_size.height .. " pixels")
    print("Position: (" .. dims.last_position.x .. "," .. dims.last_position.y .. ")")
    print("--------------------------------")
    
    -- Wait for user to press enter before continuing
    print("Press Enter to continue...")
    io.read()
    return dims
end

-- Now test with different module sizes at the same position
local position_x = 200
local position_y = 200

-- Test with small module size (5 pixels)
local small_dims = test_qr_dimensions(5, position_x, position_y)

-- Test with medium module size (8 pixels - default)
local medium_dims = test_qr_dimensions(8, position_x, position_y)

-- Test with large module size (12 pixels)
local large_dims = test_qr_dimensions(12, position_x, position_y)

-- Compare the dimensions
print("\n===== DIMENSION COMPARISON =====")
print("Small module (5px): " .. small_dims.total_size.width .. "x" .. small_dims.total_size.height .. " pixels")
print("Medium module (8px): " .. medium_dims.total_size.width .. "x" .. medium_dims.total_size.height .. " pixels")
print("Large module (12px): " .. large_dims.total_size.width .. "x" .. large_dims.total_size.height .. " pixels")
print("================================")

-- Test with custom border and title settings
print("\n----- Testing with custom border and title settings -----")
print("Setting border size to 5 pixels and removing title...")
send_to_data_mapper("qr/appearance", '{"module_size":8,"border_size":5,"title_height":0,"title_text":""}')

-- Generate and draw the QR code again
qrcode_overlay.handle_remote_trigger("3")
qrcode_overlay.draw_qr(position_x, position_y)

-- Get and display the dimensions
local custom_dims = qrcode_overlay.get_dimensions()
print("\n--- CUSTOM SETTINGS DIMENSIONS ---")
print("Matrix size: " .. custom_dims.matrix_size.width .. "x" .. custom_dims.matrix_size.height .. " modules")
print("Module size: " .. custom_dims.module_size .. " pixels")
print("QR code size: " .. custom_dims.pixel_size.width .. "x" .. custom_dims.pixel_size.height .. " pixels")
print("Border size: " .. custom_dims.border_size .. " pixels")
print("Title height: " .. custom_dims.title_height .. " pixels")
print("Total rendered size: " .. custom_dims.total_size.width .. "x" .. custom_dims.total_size.height .. " pixels")
print("Position: (" .. custom_dims.last_position.x .. "," .. custom_dims.last_position.y .. ")")
print("--------------------------------")

print("\nQR code dimension debugging complete!") 