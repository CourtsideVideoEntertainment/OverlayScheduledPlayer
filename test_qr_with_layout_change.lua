-- test_qr_with_layout_change.lua
-- This script tests QR code visibility with layout changes, focusing on trigger 16

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
        return {
            draw = function(self, x1, y1, x2, y2) end
        }
    end,
    
    load_font = function(font)
        return {
            write = function(self, x, y, text, size, r, g, b, a) end,
            width = function(self, text, size) return #text * size * 0.6 end
        }
    end,
    
    open_file = function(filename)
        return filename
    end
}

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
    print("Expiry time: " .. tostring(status.expiry_time))
    print("Remaining: " .. tostring(status.remaining))
    print("================")
end

-- Test URL generation for QR code
local function test_url_generation()
    print("\n===== URL GENERATION TEST =====")
    
    -- Generate mock asset URL for QR code
    local asset_id = "12345"
    local tile_id = "7890"
    local timestamp = "0505252338" -- Mock timestamp
    
    local url = "http://activations.courtsidevideo.com?asset_id=" .. asset_id .. 
                "&timestamp=" .. timestamp .. "&tile_id=" .. tile_id
    
    print("Generated URL: " .. url)
    print("===== URL GENERATION TEST COMPLETE =====\n")
    
    return url
end

-- Test function for trigger handling
local function test_triggers()
    print("\n===== TESTING TRIGGERS WITH LAYOUTS =====\n")
    local url = test_url_generation()
    
    -- Test QR code with trigger 3 (should display QR)
    print("\n[TEST 1] Activating trigger 3...")
    local result1 = qrcode_overlay.handle_remote_trigger("3")
    print("Trigger 3 activation result:", result1)
    print_qr_status()
    
    -- Test drawing at position
    local drawn1 = qrcode_overlay.draw_qr(100, 100)
    print("QR drawn at (100,100):", drawn1)
    
    -- Switch to different layout (trigger 5)
    print("\n[TEST 2] Switching to layout trigger 5...")
    local result2 = qrcode_overlay.handle_remote_trigger("5")
    print("Trigger 5 activation result:", result2)
    print_qr_status()
    
    -- Test drawing at position (should not draw)
    local drawn2 = qrcode_overlay.draw_qr(100, 100)
    print("QR drawn at (100,100):", drawn2)
    
    -- Switch back to trigger 3
    print("\n[TEST 3] Switching back to trigger 3...")
    local result3 = qrcode_overlay.handle_remote_trigger("3")
    print("Trigger 3 activation result:", result3)
    print_qr_status()
    
    -- Test drawing again (should draw)
    local drawn3 = qrcode_overlay.draw_qr(100, 100)
    print("QR drawn at (100,100):", drawn3)
    
    -- Explicitly hide with trigger 4
    print("\n[TEST 4] Hiding with trigger 4...")
    local result4 = qrcode_overlay.handle_remote_trigger("4")
    print("Trigger 4 activation result:", result4)
    print_qr_status()
    
    -- Test drawing (should not draw)
    local drawn4 = qrcode_overlay.draw_qr(100, 100)
    print("QR drawn at (100,100):", drawn4)
    
    print("\n===== TRIGGER TESTING COMPLETED =====")
end

-- Run the test
print("\n*** STARTING QR CODE WITH LAYOUT CHANGE TEST ***\n")
test_triggers() 