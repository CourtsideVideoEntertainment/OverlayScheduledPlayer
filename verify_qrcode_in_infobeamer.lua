#!/usr/bin/env lua
-- This script should be run directly on the info-beamer system to verify QR code functionality

print("Starting QR code verification in info-beamer environment...")

-- Add a timestamp to the debug messages
local function timestamped_print(msg)
    local date = os.date("%Y-%m-%d %H:%M:%S")
    print(string.format("[%s] %s", date, msg))
end

-- Try to load the qrcode_overlay module
timestamped_print("Loading qrcode_overlay module...")
local ok, qrcode_overlay = pcall(function() return require "qrcode_overlay" end)
if not ok then
    timestamped_print("ERROR loading qrcode_overlay: " .. tostring(qrcode_overlay))
    return
end
timestamped_print("qrcode_overlay module loaded successfully")

-- Test remote trigger 3
timestamped_print("Testing remote trigger 3...")
local result = qrcode_overlay.handle_remote_trigger("3")
timestamped_print("Remote trigger result: " .. tostring(result))

-- Check if QR matrix file was generated
local f = io.open("./qr_matrix.txt", "r")
if f then
    timestamped_print("QR matrix file was created successfully")
    f:close()
else
    timestamped_print("ERROR: QR matrix file was not created")
end

-- Print instructions for testing the QR code display
timestamped_print("QR code generation test complete.")
timestamped_print("")
timestamped_print("==== VERIFICATION INSTRUCTIONS ====")
timestamped_print("To test the QR code display in info-beamer:")
timestamped_print("1. The QR code should now be visible in the center of the screen")
timestamped_print("2. The QR code should have a dark semi-transparent background")
timestamped_print("3. The QR code should have a 'Scan QR Code' title above it")
timestamped_print("4. The QR code should automatically disappear after 60 seconds")
timestamped_print("5. You can test the URL by scanning the QR code with your phone")
timestamped_print("")
timestamped_print("You can verify in the logs that the QR code is properly being drawn")
timestamped_print("by looking for 'DEBUG: Drawing QR code at position:' messages.")
timestamped_print("==================================") 