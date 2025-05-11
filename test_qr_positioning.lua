-- test_qr_positioning.lua
-- This script demonstrates how to adjust QR code positioning and appearance

-- Simple JSON encoder for tables (limited to what we need for this demo)
local function simple_encode(t)
    if type(t) ~= "table" then
        return tostring(t)
    end
    
    local json_str = "{"
    local first = true
    
    for k, v in pairs(t) do
        if not first then
            json_str = json_str .. ","
        end
        
        json_str = json_str .. '"' .. k .. '":'
        
        if type(v) == "table" then
            json_str = json_str .. "["
            for i, val in ipairs(v) do
                if i > 1 then
                    json_str = json_str .. ","
                end
                json_str = json_str .. tostring(val)
            end
            json_str = json_str .. "]"
        elseif type(v) == "string" then
            json_str = json_str .. '"' .. v .. '"'
        else
            json_str = json_str .. tostring(v)
        end
        
        first = false
    end
    
    return json_str .. "}"
end

print("ADJUSTING QR CODE POSITIONING AND APPEARANCE")
print("--------------------------------------------")

-- Function to simulate sending data to data_mapper
local function send_to_data_mapper(channel, data)
    print("\nSending data to channel: " .. channel)
    print("Data: " .. data)
    print("--------------------")
end

-- Examples of adjusting QR code position
print("\n1. Moving QR code to bottom-right corner:")
local position_settings = {
    position = "bottom-right",
    width = 150,
    height = 150,
    margin = 30
}
send_to_data_mapper("qr/position", simple_encode(position_settings))

print("\n2. Moving QR code to top-left corner:")
position_settings = {
    position = "top-left",
    width = 150,
    height = 150,
    margin = 50
}
send_to_data_mapper("qr/position", simple_encode(position_settings))

print("\n3. Using a custom position:")
position_settings = {
    position = "custom",
    width = 200,
    height = 200,
    custom_x = 500,
    custom_y = 400
}
send_to_data_mapper("qr/position", simple_encode(position_settings))

-- Examples of adjusting QR code appearance
print("\n4. Making QR code larger with a different title:")
local appearance_settings = {
    module_size = 12,  -- Larger modules
    title_text = "Scan this QR code",
    title_font_size = 30,
    border_size = 20
}
send_to_data_mapper("qr/appearance", simple_encode(appearance_settings))

print("\n5. Changing colors and transparency:")
appearance_settings = {
    background_color = {0.2, 0.2, 0.2, 0.7},  -- Dark gray with 70% opacity
    foreground_color = {0, 0, 0.8, 1},       -- Blue QR code
    title_color = {1, 0.8, 0, 1}              -- Gold title text
}
send_to_data_mapper("qr/appearance", simple_encode(appearance_settings))

print("\n6. Minimalist QR code (smaller border, no title):")
appearance_settings = {
    module_size = 8,
    border_size = 5,
    title_height = 0,
    title_text = ""
}
send_to_data_mapper("qr/appearance", simple_encode(appearance_settings))

print("\nINSTRUCTIONS FOR USE:")
print("--------------------")
print("To adjust the QR code positioning in your application, send a JSON message to 'qr/position' with any of these properties:")
print("- position: 'top-left', 'top-right', 'bottom-left', 'bottom-right', or 'custom'")
print("- width: Width of the QR code area in pixels")
print("- height: Height of the QR code area in pixels")
print("- margin: Margin from the screen edges in pixels")
print("- custom_x: X coordinate if using custom position")
print("- custom_y: Y coordinate if using custom position")

print("\nTo adjust the QR code appearance, send a JSON message to 'qr/appearance' with any of these properties:")
print("- module_size: Size of each QR code module (square) in pixels")
print("- background_color: Array [r, g, b, a] for background color")
print("- foreground_color: Array [r, g, b, a] for QR code color")
print("- border_size: Size of border around QR code")
print("- title_text: Text displayed above QR code")
print("- title_height: Height of title area")
print("- title_font_size: Font size for title")
print("- title_color: Array [r, g, b, a] for title text color")

print("\nExample command to position QR code in bottom-right corner:")
print('echo \'{"position":"bottom-right","width":150,"height":150,"margin":30}\' > qr/position')

print("\nExample command to make QR code blue with gold title:")
print('echo \'{"foreground_color":[0,0,0.8,1],"title_color":[1,0.8,0,1]}\' > qr/appearance') 