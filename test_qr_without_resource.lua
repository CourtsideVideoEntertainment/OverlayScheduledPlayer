-- test_qr_without_resource.lua
-- This script tests QR code behavior when the resource global is not available

-- Mock these globals for testing outside of info-beamer, but DO NOT mock resource
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

-- Explicitly set resource to nil to simulate the issue
resource = nil

-- Create initialization function
local function init_qrcode()
    package.path = package.path .. ";?.lua"
    print("Initializing QR code module...")
    local qrcode = require("qrcode_overlay")
    print("QR code module loaded successfully")
    return qrcode
end

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
local function print_qr_status(qrcode)
    local status = qrcode.get_status()
    print("=== QR STATUS ===")
    print("Visible: " .. tostring(status.visible))
    print("Permanent: " .. tostring(status.permanent))
    print("Current Trigger: " .. tostring(status.current_trigger))
    print("Has Draw Function: " .. tostring(status.has_draw_function))
    print("================")
end

-- Test function
local function test_without_resource()
    print("\n===== TESTING QR CODE WITHOUT RESOURCE GLOBAL =====\n")
    
    -- Check if resource is really nil
    print("Resource global is nil:", resource == nil)
    
    -- Initialize QR code module
    local qrcode = init_qrcode()
    if not qrcode then
        print("ERROR: Failed to initialize QR code module")
        return
    end
    
    -- Test trigger 16 (video content)
    print("\n[TEST] Activating trigger 16 (video content)...")
    local result = qrcode.handle_remote_trigger("16")
    print("Trigger activation result:", result)
    print_qr_status(qrcode)
    
    -- Try to draw the QR code (should fail gracefully)
    local drawn = qrcode.draw_qr(100, 100)
    print("QR drawn:", drawn)
    
    -- Switch to trigger 4 (should hide)
    print("\n[TEST] Explicitly hiding with trigger 4...")
    local result2 = qrcode.handle_remote_trigger("4")
    print("Trigger 4 activation result:", result2)
    print_qr_status(qrcode)
    
    print("\n===== TESTING WITHOUT RESOURCE COMPLETED =====")
end

-- Run the test
print("\n*** STARTING QR CODE TEST WITHOUT RESOURCE ***\n")
test_without_resource() 