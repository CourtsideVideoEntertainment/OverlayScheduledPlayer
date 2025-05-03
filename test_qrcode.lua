-- Test script for QR code functionality

-- Define mock functions to simulate the info-beamer runtime environment
_G.resource = { 
    create_colored_texture = function(r, g, b, a) 
        print(string.format("Creating texture with color: %.1f, %.1f, %.1f, %.1f", r, g, b, a))
        return {
            draw = function(self, x1, y1, x2, y2, alpha)
                alpha = alpha or 1
                print(string.format("Drawing texture at: %.1f, %.1f, %.1f, %.1f with alpha %.1f", 
                    x1, y1, x2, y2, alpha))
            end
        }
    end
}

_G.sys = { 
    now = function() 
        return os.time()  -- Use real timestamp for testing
    end 
}

-- Now require the overlay module
local qrcode_overlay = require "qrcode_overlay"

print("Starting QR code test...")

-- Test handle_remote_trigger function with trigger 3
print("\nTesting remote trigger 3...")
local success = qrcode_overlay.handle_remote_trigger("3")
print("Remote trigger result:", success)

-- Check if the QR matrix file was created
local f = io.open("qr_matrix.txt", "r")
if f then
    print("QR matrix file was created successfully")
    f:close()
else
    print("ERROR: QR matrix file was not created")
end

-- Test draw_qr function
print("\nTesting draw_qr function...")
print("Should return true (QR code should be displayed):")
local display_result = qrcode_overlay.draw_qr(100, 100)
print("QR code display result:", display_result)

-- Test QR code expiry - simulate time passing
_G.sys.now = function() return os.time() + 100 end  -- Set time 100 seconds in the future
print("\nTesting QR code expiry...")
local expired_result = qrcode_overlay.draw_qr(100, 100)
print("QR code display after expiry:", expired_result)

print("\nQR code test completed") 