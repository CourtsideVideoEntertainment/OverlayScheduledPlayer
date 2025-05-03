-- Test script for QR code functionality in info-beamer environment
print("Starting info-beamer QR code test...")

-- Mock the necessary info-beamer environment
_G.sys = {
    now = function() return os.time() end
}

_G.resource = {
    create_colored_texture = function(r, g, b, a)
        print("Creating texture with color:", r, g, b, a)
        return {
            draw = function(self, x1, y1, x2, y2, alpha)
                print(string.format("Drawing texture at: %.1f, %.1f, %.1f, %.1f with alpha %.1f", x1, y1, x2, y2, alpha or 1.0))
                return true
            end
        }
    end,
    create_render_target = function(w, h)
        print("Creating render target:", w, h)
        return {
            draw = function(self, x1, y1, x2, y2, alpha)
                print(string.format("Drawing render target at: %.1f, %.1f, %.1f, %.1f with alpha %.1f", x1, y1, x2, y2, alpha or 1.0))
                return true
            end
        }
    end,
    load_font = function(font)
        print("Loading font:", font)
        return {
            write = function(self, x, y, text, size, r, g, b, a)
                print(string.format("Writing text '%s' at position %.1f,%.1f with size %.1f", text, x, y, size))
                return true
            end
        }
    end
}

-- Mock the required info-beamer functions
_G.node = {
    render = function() end
}

-- Load the qrcode_overlay module
print("Loading qrcode_overlay module...")
local ok, qrcode_overlay = pcall(function() return require "qrcode_overlay" end)
if not ok then
    print("Error loading qrcode_overlay:", qrcode_overlay)
    return
end
print("qrcode_overlay module loaded successfully")

-- Test generating QR code
print("\nTesting handle_remote_trigger with trigger 3...")
local result = qrcode_overlay.handle_remote_trigger("3")
print("Remote trigger result: ", result)

-- Check if QR matrix file was created
local f = io.open("./qr_matrix.txt", "r")
if f then
    print("QR matrix file was created successfully")
    f:close()
else
    print("ERROR: QR matrix file was not created")
end

-- Regenerate QR code for drawing test
qrcode_overlay.handle_remote_trigger("3")

-- Test QR code drawing
print("\nTesting draw_qr function...")
local x, y = 100, 100
local success, result = pcall(function() return qrcode_overlay.draw_qr(x, y) end)
if not success then
    print("ERROR during QR drawing:", result)
    result = false
end
print("QR code drawing result:", result)

-- Test QR code expiry
print("\nTesting QR code expiry...")
qrcode_overlay.qr_expiry_time = 0  -- Force expiry
success, result = pcall(function() return qrcode_overlay.draw_qr(x, y) end)
if not success then
    print("ERROR during QR expiry test:", result)
    result = false
else
    print("QR code expiry test completed successfully")
end
print("QR code drawing after expiry:", result)

print("\nInfo-beamer QR code test completed")

-- Clean up
os.remove("./qr_matrix.txt")
print("Cleaned up QR matrix file") 