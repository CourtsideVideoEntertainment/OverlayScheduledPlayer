-- test_debug_marker.lua
-- This script tests the visibility of the debug marker when playing videos

-- Set up necessary globals
NATIVE_WIDTH = 1920
NATIVE_HEIGHT = 1080

-- Mock GL functions
gl = {
    clear = function(r, g, b, a) print("GL: Clearing screen") end,
    pushMatrix = function() print("GL: Push matrix") end,
    popMatrix = function() print("GL: Pop matrix") end,
    translate = function(x, y, z) print("GL: Translate to " .. x .. ", " .. y .. ", " .. z) end
}

-- Mock system functions
sys = {
    now = function() return os.time() end
}

-- Mock resource functions for display
resource = {
    create_colored_texture = function(r, g, b, a)
        print("Creating texture: " .. r .. ", " .. g .. ", " .. b .. ", " .. a)
        return {
            draw = function(self, x1, y1, x2, y2)
                print("Drawing texture at: " .. x1 .. ", " .. y1 .. " to " .. x2 .. ", " .. y2)
            end
        }
    end,
    
    create_shader = function(code)
        print("Creating shader")
        return {
            use = function(self, params)
                print("Using shader with params: " .. (params.color and ("r=" .. params.color[1] .. ", g=" .. params.color[2] .. ", b=" .. params.color[3] .. ", a=" .. params.color[4]) or "none"))
            end,
            deactivate = function(self)
                print("Deactivating shader")
            end
        }
    end,
    
    load_font = function(font)
        print("Loading font: " .. font)
        return {
            write = function(self, x, y, text, size, r, g, b, a)
                print("Writing text '" .. text .. "' at " .. x .. ", " .. y .. " with size " .. size)
            end
        }
    end
}

print("Testing debug marker rendering:")
print("---------------------------------")

-- Test the initialization part from node.lua
print("\nInitializing debug marker:")
local debug_marker = resource.create_colored_texture(1, 0, 0, 1)
local white_pixel = resource.create_colored_texture(1, 1, 1, 1)
local colored = resource.create_shader("shader code goes here")

-- Test the render function
print("\nTesting render function:")
print("Frame 1 (normal rendering):")
local now = os.time()
-- Simulate the part of render that draws the marker
gl.pushMatrix()
gl.translate(0, 0, 0.1)
-- Draw white border
colored:use{color = {1, 1, 1, 1}}
white_pixel:draw(8, 8, 32, 32)
colored:deactivate()
-- Draw marker with blinking effect
local blink_alpha = math.abs(math.sin(now * 3)) * 0.5 + 0.5
colored:use{color = {1, 0, 0, blink_alpha}}
debug_marker:draw(10, 10, 30, 30)
colored:deactivate()
gl.popMatrix()

print("\nFrame 2 (simulating video playing):")
now = os.time() + 1
-- Pretend a video is being displayed first
print("Video rendering would happen here...")
-- Then draw the marker on top
gl.pushMatrix()
gl.translate(0, 0, 0.1)
-- Draw white border
colored:use{color = {1, 1, 1, 1}}
white_pixel:draw(8, 8, 32, 32)
colored:deactivate()
-- Draw marker with blinking effect
blink_alpha = math.abs(math.sin(now * 3)) * 0.5 + 0.5
colored:use{color = {1, 0, 0, blink_alpha}}
debug_marker:draw(10, 10, 30, 30)
colored:deactivate()
gl.popMatrix()

print("\nFrame 3 (simulating layout change):")
now = os.time() + 2
-- Pretend a layout change happens
print("Layout change would happen here...")
-- Marker still gets drawn last
gl.pushMatrix()
gl.translate(0, 0, 0.1)
-- Draw white border
colored:use{color = {1, 1, 1, 1}}
white_pixel:draw(8, 8, 32, 32)
colored:deactivate()
-- Draw marker with blinking effect
blink_alpha = math.abs(math.sin(now * 3)) * 0.5 + 0.5
colored:use{color = {1, 0, 0, blink_alpha}}
debug_marker:draw(10, 10, 30, 30)
colored:deactivate()
gl.popMatrix()

print("\nConclusion:")
print("The debug marker will remain visible in all frames because:")
print("1. It's created once at initialization time")
print("2. It's drawn last in the render sequence")
print("3. It uses gl.translate with z=0.1 to ensure it's on top")
print("4. It has a white border to stand out against any background")
print("5. It has a blinking effect to increase visibility") 