-- test_qr_code_visibility.lua
-- This script tests QR code visibility with different triggers, focusing on trigger 16 for video

-- Mock these globals for testing outside of info-beamer
NATIVE_WIDTH = 1920
NATIVE_HEIGHT = 1080

-- Mock system functions
sys = {
    now = function() return os.time() end
}

-- Mock GL functions
gl = {
    clear = function(r, g, b, a) print("GL: Clearing screen") end,
    pushMatrix = function() end,
    popMatrix = function() end
}

-- Mock resource functions for display
resource = {
    create_colored_texture = function(r, g, b, a)
        print(string.format("Creating texture: %.1f, %.1f, %.1f, %.1f", r, g, b, a))
        return {
            draw = function(self, x1, y1, x2, y2)
                print(string.format("Drawing texture at: %.1f, %.1f to %.1f, %.1f", x1, y1, x2, y2))
            end
        }
    end,
    
    load_font = function(font)
        print("Loading font: " .. font)
        return {
            write = function(self, x, y, text, size, r, g, b, a)
                print(string.format("Writing text '%s' at %.1f, %.1f with size %.1f", text, x, y, size))
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
    print("=== QR STATUS ===")
    print("Visible: " .. tostring(status.visible))
    print("Permanent: " .. tostring(status.permanent))
    print("Current Trigger: " .. tostring(status.current_trigger))
    print("Has Draw Function: " .. tostring(status.has_draw_function))
    print("================")
end

-- Helper function to simulate rendering
local function render_frame(x, y)
    print("\nSimulating a render frame")
    print("Drawing test marker...")
    -- Draw red marker
    local mock_marker = resource.create_colored_texture(1, 0, 0, 1)
    mock_marker:draw(10, 10, 30, 30)
    
    -- Try to draw QR code
    print("Attempting to draw QR code...")
    local drawn = qrcode_overlay.draw_qr(x, y)
    print("QR code drawn result:", drawn)
    return drawn
end

-- Test function to verify QR code visibility
local function test_qr_visibility()
    print("\n===== TESTING QR CODE VISIBILITY =====\n")
    
    -- First test with trigger 16 (video content)
    print("\n[TEST 1] Activating trigger 16 (video content)...")
    local result = qrcode_overlay.handle_remote_trigger("16")
    print("Trigger 16 activation result:", result)
    print_qr_status()
    
    -- Simulate render frame
    render_frame(100, 100)
    
    -- Switch to a different trigger (should hide QR)
    print("\n[TEST 2] Switching to trigger 5 (should hide QR code)...")
    local result2 = qrcode_overlay.handle_remote_trigger("5")
    print("Trigger 5 activation result:", result2)
    print_qr_status()
    
    -- Simulate render frame
    render_frame(100, 100)
    
    -- Switch back to trigger 16 (should show QR again)
    print("\n[TEST 3] Switching back to trigger 16 (should show QR code again)...")
    local result3 = qrcode_overlay.handle_remote_trigger("16")
    print("Trigger 16 activation result:", result3)
    print_qr_status()
    
    -- Simulate render frame
    render_frame(100, 100)
    
    -- Test multiple render frames to ensure QR code stays visible
    print("\n[TEST 4] Testing multiple render frames with trigger 16...")
    for i = 1, 3 do
        print("\nRender frame", i)
        render_frame(100, 100)
    end
    
    -- Switch to trigger 3 (regular trigger)
    print("\n[TEST 5] Switching to trigger 3...")
    local result4 = qrcode_overlay.handle_remote_trigger("3")
    print("Trigger 3 activation result:", result4)
    print_qr_status()
    
    -- Simulate render frame
    render_frame(100, 100)
    
    -- Explicitly hide QR code with trigger 4
    print("\n[TEST 6] Explicitly hiding QR code with trigger 4...")
    local result5 = qrcode_overlay.handle_remote_trigger("4")
    print("Trigger 4 activation result:", result5)
    print_qr_status()
    
    -- Simulate render frame
    render_frame(100, 100)
    
    print("\n===== QR CODE VISIBILITY TESTING COMPLETED =====")
end

-- Run the test
print("\n*** STARTING QR CODE VISIBILITY TEST ***\n")
test_qr_visibility() 