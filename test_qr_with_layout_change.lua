-- test_qr_with_layout_change.lua
-- This script tests the QR code display behavior when switching between layouts/triggers

-- Mock these globals for testing outside of info-beamer
-- Set up necessary globals
NATIVE_WIDTH = 1920
NATIVE_HEIGHT = 1080

-- Mock system functions
sys = {
    now = function() return os.time() end
}

-- Mock GL functions
gl = {
    clear = function(r, g, b, a) print("GL: Clearing screen") end
}

-- Mock resource functions for display
resource = {
    create_colored_texture = function(r, g, b, a)
        print("Creating texture: " .. r .. ", " .. g .. ", " .. b .. ", " .. a)
        return {
            draw = function(self, x1, y1, x2, y2)
                print("Drawing texture at: " .. x1 .. ", " .. y1 .. " to " .. x2 .. ", " .. y2)
            end
        }
    end,
    
    load_font = function(font)
        print("Loading font: " .. font)
        return {
            write = function(self, x, y, text, size, r, g, b, a)
                print("Writing text '" .. text .. "' at " .. x .. ", " .. y .. " with size " .. size)
            end
        }
    end,
    
    open_file = function(filename)
        print("Opening file: " .. filename)
        return filename
    end
}

-- Create no-op functions for functionality we don't need to test
local function noop(...) return true end

-- Load the actual QR code module
package.path = package.path .. ";?.lua"
print("Loading qrcode_overlay module...")
local qrcode_overlay = require("qrcode_overlay")

-- Mock qrencode module for the test
package.loaded.qrencode = {
    qrcode = function(data)
        print("Mock qrencode: Creating QR code for " .. data)
        -- Create a simple 10x10 matrix
        local matrix = {}
        for i = 1, 10 do
            matrix[i] = {}
            for j = 1, 10 do
                matrix[i][j] = ((i + j) % 2) -- Simple checkerboard pattern
            end
        end
        return true, matrix
    end
}

-- Helper function to print QR status
local function print_qr_status()
    local status = qrcode_overlay.get_status()
    print("QR STATUS: visible=" .. tostring(status.visible) ..
          ", permanent=" .. tostring(status.permanent) ..
          ", trigger=" .. tostring(status.current_trigger) ..
          ", has_draw_function=" .. tostring(status.has_draw_function))
end

-- Test function to verify QR code display behavior
local function test_layout_changes()
    print("\n===== TESTING QR CODE DISPLAY WITH LAYOUT CHANGES =====\n")
    
    -- First trigger layout 3 (should display QR code)
    print("\nTesting trigger 3 - should show QR code...")
    local result = qrcode_overlay.handle_remote_trigger("3")
    print("Trigger 3 result:", result)
    print("QR code visible:", qrcode_overlay.show_qr())
    print_qr_status()
    
    -- Display QR code
    print("\nDrawing QR code after trigger 3...")
    local drawn = qrcode_overlay.draw_qr(100, 100)
    print("QR drawn successfully:", drawn)
    
    -- Switch to another layout (trigger 5) - should hide QR code
    print("\nSwitching to trigger 5 - should hide QR code...")
    local result2 = qrcode_overlay.handle_remote_trigger("5")
    print("Trigger 5 result:", result2)
    print("QR code visible:", qrcode_overlay.show_qr())
    print_qr_status()
    
    -- Try to draw QR code - should fail
    print("\nTrying to draw QR code after trigger 5...")
    local drawn2 = qrcode_overlay.draw_qr(100, 100)
    print("QR drawn successfully:", drawn2)
    
    -- Go back to layout 3 - should show QR code again
    print("\nSwitching back to trigger 3 - should show QR code again...")
    local result3 = qrcode_overlay.handle_remote_trigger("3")
    print("Trigger 3 result:", result3)
    print("QR code visible:", qrcode_overlay.show_qr())
    print_qr_status()
    
    -- Draw QR code again
    print("\nDrawing QR code after returning to trigger 3...")
    local drawn3 = qrcode_overlay.draw_qr(100, 100)
    print("QR drawn successfully:", drawn3)
    
    -- Explicitly hide with trigger 4
    print("\nExplicitly hiding with trigger 4...")
    local result4 = qrcode_overlay.handle_remote_trigger("4")
    print("Trigger 4 result:", result4)
    print("QR code visible:", qrcode_overlay.show_qr())
    print_qr_status()
    
    print("\n===== TEST COMPLETED =====")
end

-- Run the test
test_layout_changes() 