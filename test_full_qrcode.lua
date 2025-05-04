#!/usr/bin/env lua

-- Simulate info-beamer environment
_G.sys = {
    now = function() return os.time() end
}

_G.resource = {
    create_colored_texture = function(r, g, b, a)
        print(string.format("Creating texture with color: %.1f, %.1f, %.1f, %.1f", r, g, b, a))
        return {
            draw = function(self, x1, y1, x2, y2, alpha)
                print(string.format("Drawing texture at: %.1f, %.1f, %.1f, %.1f with alpha %.1f", 
                    x1, y1, x2, y2, alpha or 1))
            end
        }
    end,
    
    load_font = function(name)
        print("Loading font: " .. name)
        return {
            write = function(self, x, y, text, size, r, g, b, a)
                print(string.format("Writing text '%s' at position %.1f,%.1f with size %.1f", 
                    text, x, y, size))
            end
        }
    end
}

-- Simulate the noglobals() functionality in info-beamer
local function noglobals()
    -- Create a metatable that prevents access to undefined globals
    local mt = getmetatable(_G) or {}
    mt.__index = function(t, k)
        error("attempt to reference missing global '" .. tostring(k) .. "' aborted: noglobals() active", 2)
    end
    setmetatable(_G, mt)
end

-- Apply the noglobals restriction
noglobals()

print("Testing full QR code generation with qrcode_overlay module...")

-- Load the qrcode_overlay module
print("Loading qrcode_overlay module...")
local qrcode_overlay = require("qrcode_overlay")

-- Test the remote trigger function
print("\nTesting remote trigger 3 for QR code generation...")
local result = qrcode_overlay.handle_remote_trigger("3")
print("QR code remote trigger result:", result)

-- Test drawing the QR code
print("\nTesting QR code drawing...")
local drawn = qrcode_overlay.draw_qr(100, 100)
print("QR code drawn:", drawn)

print("\nTest completed successfully!") 