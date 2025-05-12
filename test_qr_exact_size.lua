#!/usr/bin/env lua
-- test_qr_exact_size.lua
-- This script demonstrates how to create QR codes with exact sizes

print("===== QR CODE EXACT SIZING DEMO =====")
print("")

-- Function to simulate sending JSON data to different channels
function send_command(channel, data_table)
    local parts = {}
    for k, v in pairs(data_table) do
        if type(v) == "string" then
            table.insert(parts, string.format('"%s":"%s"', k, v))
        else
            table.insert(parts, string.format('"%s":%s', k, v))
        end
    end
    local data = "{" .. table.concat(parts, ",") .. "}"
    
    print("SEND TO CHANNEL: " .. channel)
    print("DATA: " .. data)
    print("")
end

print("EXAMPLE 1: Creating a small 100x100 pixel QR code in the bottom-right corner")
print("----------------------------------------------------------------------")

-- Step 1: First set the position in the bottom-right corner with exact size
send_command("qr/position", {
    position = "bottom-right",
    width = 100,       -- Exact width in pixels
    height = 100,      -- Exact height in pixels
    margin = 20        -- Margin from the screen edge in pixels
})

-- Step 2: Set the appearance with reduced border and no title to maximize QR code area
send_command("qr/appearance", {
    module_size = 3,   -- This will be automatically adjusted to fit the exact size
    border_size = 5,   -- Smaller border
    title_text = "",   -- No title
    title_height = 0   -- No title height
})

-- Step 3: Trigger the QR code to show
send_command("remote/trigger", {
    action = "show_qr",
    trigger = "1"
})

print("")
print("EXAMPLE 2: Creating a medium 200x200 pixel QR code at custom position")
print("----------------------------------------------------------------------")

-- Step 1: Set a custom position with exact size
send_command("qr/position", {
    position = "custom",
    width = 200,       -- Exact width in pixels
    height = 200,      -- Exact height in pixels
    custom_x = 400,    -- X coordinate (from left)
    custom_y = 300     -- Y coordinate (from top)
})

-- Step 2: Set the appearance with a border and title
send_command("qr/appearance", {
    module_size = 5,   -- Will be automatically adjusted
    border_size = 10,  -- Medium border
    title_text = "Scan Me!",
    title_height = 30,
    title_font_size = 20,
    title_color = "#FFFFFF",
    background_color = "#000000",
    foreground_color = "#FFFFFF"
})

-- Step 3: Trigger the QR code to show
send_command("remote/trigger", {
    action = "show_qr",
    trigger = "2"
})

print("")
print("EXAMPLE 3: Creating a large 300x300 pixel QR code in the top-left corner")
print("----------------------------------------------------------------------")

-- Step 1: Set the position in the top-left corner with exact size
send_command("qr/position", {
    position = "top-left",
    width = 300,       -- Exact width in pixels
    height = 300,      -- Exact height in pixels
    margin = 30        -- Margin from the screen edge in pixels
})

-- Step 2: Set the appearance with a colorful style
send_command("qr/appearance", {
    module_size = 7,   -- Will be automatically adjusted
    border_size = 15,  -- Larger border
    title_text = "Scan for more info",
    title_height = 40,
    title_font_size = 24,
    title_color = "#FFD700", -- Gold color for title
    background_color = "#0000AA", -- Dark blue background
    foreground_color = "#00FF00"  -- Green QR code
})

-- Step 3: Trigger the QR code to show
send_command("remote/trigger", {
    action = "show_qr", 
    trigger = "3"
})

print("")
print("EXAMPLE 4: Showing a very small 50x50 pixel QR code")
print("----------------------------------------------------------------------")

-- Step 1: Set a custom position with a small exact size
send_command("qr/position", {
    position = "custom",
    width = 50,        -- Very small width
    height = 50,       -- Very small height
    custom_x = 100,    -- X coordinate (from left)
    custom_y = 100     -- Y coordinate (from top)
})

-- Step 2: Set the appearance with minimal border and no title
send_command("qr/appearance", {
    module_size = 1,   -- Will be automatically adjusted to be very small
    border_size = 2,   -- Minimal border
    title_text = "",   -- No title
    title_height = 0   -- No title height
})

-- Step 3: Trigger the QR code to show
send_command("remote/trigger", {
    action = "show_qr",
    trigger = "4"
})

print("")
print("===== HOW TO USE THESE COMMANDS =====")
print("")
print("To use these commands in your application:")
print("1. First set the position with 'qr/position' channel")
print("2. Then set the appearance with 'qr/appearance' channel")
print("3. Finally, trigger the QR code display with 'remote/trigger'")
print("")
print("You can specify the exact size of your QR code using the 'width' and 'height' parameters")
print("in the qr/position channel. The QR code will be scaled to match those dimensions exactly.")
print("")
print("NOTE: Very small QR codes might be hard to scan, especially with complex URLs.")
print("A good minimum size is around 100x100 pixels for most phone cameras.")
print("")
print("NOTE: The module_size parameter will be automatically adjusted to achieve the exact size")
print("you specified in width and height.")
print("") 