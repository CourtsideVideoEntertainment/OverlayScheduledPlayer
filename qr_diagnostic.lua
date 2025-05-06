-- qr_diagnostic.lua
-- Diagnostic script to troubleshoot QR code display issues

-- Mock these globals for testing outside of info-beamer
NATIVE_WIDTH = 1920
NATIVE_HEIGHT = 1080

-- Mock system functions
sys = {
    now = function() return os.time() end
}

-- Load the actual QR code module
package.path = package.path .. ";?.lua"
print("Loading qrcode_overlay module...")
local qrcode_overlay = require("qrcode_overlay")

-- Add diagnostic wrapper for qrencode
local original_qrencode = package.loaded.qrencode
if not original_qrencode then
    print("WARNING: qrencode module not found - will attempt to mock it")
    package.loaded.qrencode = {
        qrcode = function(data)
            print("MOCK qrencode: Creating QR code for " .. data)
            -- Create a simple matrix
            local matrix = {}
            for i = 1, 10 do
                matrix[i] = {}
                for j = 1, 10 do
                    matrix[i][j] = ((i + j) % 2)
                end
            end
            return true, matrix
        end
    }
end

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

-- Check if qrencode is available
local function check_qrencode()
    print("\n=== CHECKING QRENCODE MODULE ===")
    if package.loaded.qrencode then
        print("qrencode module is loaded")
        if type(package.loaded.qrencode.qrcode) == "function" then
            print("qrcode function is available")
            -- Try generating a test QR code
            local ok, matrix = package.loaded.qrencode.qrcode("TEST")
            if ok and matrix then
                print("QR code generation successful")
                print("Matrix size: " .. #matrix .. "x" .. #matrix[1])
                return true
            else
                print("QR code generation FAILED")
                return false
            end
        else
            print("ERROR: qrcode function is NOT available")
            return false
        end
    else
        print("ERROR: qrencode module is NOT loaded")
        return false
    end
end

-- Test the QR code with various triggers
local function test_qr_with_triggers()
    print("\n=== TESTING QR CODE WITH VARIOUS TRIGGERS ===")
    
    -- Generate the triggers we want to test
    local triggers = {"16", "3", "3p", "4", "5"}
    
    for _, trigger in ipairs(triggers) do
        print("\nTesting trigger: " .. trigger)
        local result = qrcode_overlay.handle_remote_trigger(trigger)
        print("Trigger " .. trigger .. " result: " .. tostring(result))
        print_qr_status()
        
        -- Try to draw the QR code
        local drawn = qrcode_overlay.draw_qr(100, 100)
        print("QR drawn: " .. tostring(drawn))
    end
end

-- Inspect the qrcode_overlay module itself
local function inspect_qrcode_module()
    print("\n=== INSPECTING QRCODE_OVERLAY MODULE ===")
    
    -- Check if important functions exist
    local functions = {
        "handle_remote_trigger",
        "draw_qr",
        "show_qr",
        "get_status"
    }
    
    for _, func_name in ipairs(functions) do
        if type(qrcode_overlay[func_name]) == "function" then
            print("Function '" .. func_name .. "' exists")
        else
            print("WARNING: Function '" .. func_name .. "' does NOT exist")
        end
    end
end

-- Run all diagnostics
local function run_diagnostics()
    print("\n*** STARTING QR CODE DIAGNOSTICS ***\n")
    
    -- First inspect the module
    inspect_qrcode_module()
    
    -- Check if qrencode is available
    local qrencode_ok = check_qrencode()
    
    -- Test with various triggers
    test_qr_with_triggers()
    
    -- Print summary
    print("\n=== DIAGNOSTIC SUMMARY ===")
    print("QR code module inspection completed")
    print("qrencode available: " .. tostring(qrencode_ok))
    print("Trigger tests completed")
    print("Check the logs above for specific issues")
    print("================")
end

-- Run the diagnostics
run_diagnostics() 