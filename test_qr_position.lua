#!/usr/bin/env lua

-- Test script for QR code positioning in info-beamer environment
print("Starting QR code positioning test...")

-- Define global variables that info-beamer would provide
_G.NATIVE_WIDTH = 1920  -- Standard HD resolution
_G.NATIVE_HEIGHT = 1080

-- Mock the necessary info-beamer environment
_G.sys = {
    now = function() return os.time() end
}

_G.gl = {
    clear = function(r, g, b, a) 
        print("GL clear:", r, g, b, a)
    end
}

_G.resource = {
    create_colored_texture = function(r, g, b, a)
        print(string.format("Creating texture with color: %.1f, %.1f, %.1f, %.1f", r, g, b, a))
        return {
            draw = function(self, x1, y1, x2, y2, alpha)
                alpha = alpha or 1.0
                print(string.format("Drawing texture at: %.1f, %.1f, %.1f, %.1f with alpha %.1f", 
                      x1, y1, x2, y2, alpha))
                return self
            end
        }
    end,
    load_font = function(font)
        print("Loading font:", font)
        return {
            write = function(self, x, y, text, size, r, g, b, a)
                print(string.format("Writing text '%s' at position %.1f,%.1f with size %.1f", 
                      text, x, y, size))
                return true
            end
        }
    end
}

-- Implement required scheduling functions as no-ops
local function noop() end
local scheduler = {
    tick = noop,
    handle_keyboard = noop,
    handle_gamepad = noop,
    handle_gpio = noop,
    handle_remote_trigger = noop,
    handle_cec = noop
}

local streams = {
    tick = noop
}

local FontCache = {
    tick = noop
}

local ImageCache = {
    tick = noop
}

local screen = {
    setup = noop
}

local dispatch_to_all_tiles = noop
local job_queue = {
    tick = noop
}

local background = {r = 0, g = 0, b = 0, a = 0}

-- Load the qrcode_overlay module
print("Loading qrcode_overlay module...")
package.path = "./?.lua;" .. package.path

-- First, let's try to load qrencode to verify it works
local qrencode_ok, qrencode = pcall(function() return require "qrencode" end)
if not qrencode_ok then
    print("Error loading qrencode:", qrencode)
else
    print("qrencode module loaded successfully")
end

local qr_ok, qrcode_overlay = pcall(function() return require "qrcode_overlay" end)
if not qr_ok then
    print("Error loading qrcode_overlay:", qrcode_overlay)
    return
end
print("qrcode_overlay module loaded successfully")

-- Test triggering QR code
print("\nTesting handle_remote_trigger with trigger 3...")
local result = qrcode_overlay.handle_remote_trigger("3")
print("Remote trigger result:", result)

-- Now test rendering
print("\nTesting QR code drawing in bottom-right corner...")

-- Override the render function to add QR code display
function render_test()
    print("Rendering frame...")
    gl.clear(background.r, background.g, background.b, background.a)

    -- Position QR code in the bottom-right corner for less interference with content
    local qr_width = 400  -- Approximate width with the smaller qr_size (10px per module)
    local qr_height = 400 -- Approximate height with the smaller qr_size
    local margin = 20     -- Margin from the screen edge
    
    local qr_x = NATIVE_WIDTH - qr_width - margin
    local qr_y = NATIVE_HEIGHT - qr_height - margin
    
    print("QR position calculated as:", qr_x, qr_y)
    
    -- Draw a test marker to verify rendering is working (small red dot in corner)
    local marker = resource.create_colored_texture(1, 0, 0, 1)  -- Red square
    marker:draw(10, 10, 30, 30)  -- Small red square in corner to confirm rendering is working
    
    -- Try to draw the QR code
    local drawn = qrcode_overlay.draw_qr(qr_x, qr_y)
    
    print("QR code drawn:", drawn)
    
    return drawn
end

-- Run the render test
render_test()

print("\nQR code positioning test completed.") 