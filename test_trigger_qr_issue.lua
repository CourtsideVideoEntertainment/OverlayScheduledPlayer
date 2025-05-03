#!/usr/bin/env lua
-- test_trigger_qr_issue.lua
-- A simplified test focusing only on the trigger 3 QR code issue

-- Set up basic mocks for the environment
_G.sys = {
    now = function() return os.time() end
}

_G.resource = {
    create_colored_texture = function(r, g, b, a)
        print("Creating texture with color:", r, g, b, a)
        return {
            draw = function(self, x1, y1, x2, y2)
                print("Drawing texture at:", x1, y1, x2, y2, "with alpha", a)
            end
        }
    end,
    load_font = function(font)
        print("Loading font:", font)
        return {
            write = function(self, x, y, text, size, r, g, b, a)
                print("Writing text '" .. text .. "' at position " .. x .. "," .. y .. " with size " .. size)
            end
        }
    end
}

-- Load the qrcode_overlay module
package.path = package.path .. ';./?.lua'
local qrcode_overlay = require("qrcode_overlay")

-- Mock the require function for qrencode to return a simple implementation
local original_require = require
_G.require = function(module)
    if module == "qrencode" then
        return {
            qrcode = function(data)
                -- Create a simple 10x10 QR code matrix (mock)
                local matrix = {}
                for i = 1, 10 do
                    matrix[i] = {}
                    for j = 1, 10 do
                        -- Create a simple pattern
                        matrix[i][j] = (i + j) % 3
                    end
                end
                return true, matrix
            end
        }
    else
        return original_require(module)
    end
end

print("\n=== Testing QR code generation and display ===")

-- Test the QR code functionality
local result = qrcode_overlay.handle_remote_trigger("3")
print("QR code handle_remote_trigger result:", result)

-- Wait a moment to simulate the system running
print("\n=== Testing QR code display after generation ===")
local should_show = qrcode_overlay.show_qr()
print("Should show QR:", should_show)

if should_show then
    print("\n=== Drawing QR code ===")
    local draw_result = qrcode_overlay.draw_qr(100, 100)
    print("QR draw result:", draw_result)
else
    print("ERROR: QR code should be showing but isn't")
end

print("\n=== Testing non-QR remote trigger ===")
local other_result = qrcode_overlay.handle_remote_trigger("4")
print("Non-QR trigger result:", other_result)

print("\nQR code trigger test completed") 