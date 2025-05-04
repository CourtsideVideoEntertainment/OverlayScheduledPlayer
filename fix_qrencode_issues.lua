#!/usr/bin/env lua

print("Fixing issues in qrencode.lua...")

-- Load the file content
local file = io.open("qrencode.lua", "r")
if not file then
    print("ERROR: Could not open qrencode.lua")
    os.exit(1)
end

local content = file:read("*all")
file:close()

-- Fix 1: Type comparison issue at line 237
-- The issue is likely in the get_version_eclevel function where it's comparing strings and numbers
-- Let's ensure all comparisons are done with the correct type

-- First, convert the requested_ec_level parameter to a number if it's passed as a string
local fixed_content = content:gsub(
    "local function get_version_eclevel%((.-)%)",
    function(params)
        return "local function get_version_eclevel(" .. params .. ")\n" ..
               "\t-- Ensure requested_ec_level is a number\n" ..
               "\tif requested_ec_level and type(requested_ec_level) == 'string' then\n" ..
               "\t\trequested_ec_level = tonumber(requested_ec_level)\n" ..
               "\tend\n"
    end
)

-- Fix 2: Fix any string formatting issues in the qrcode_overlay.lua file
local overlay_file = io.open("qrcode_overlay.lua", "r")
if not overlay_file then
    print("ERROR: Could not open qrcode_overlay.lua")
    os.exit(1)
end

local overlay_content = overlay_file:read("*all")
overlay_file:close()

-- Fix any string formatting issues where number is expected but string is passed
local fixed_overlay = overlay_content:gsub(
    "(string%.format%([^,]+,[^,]+,[^,]+,[^,]+,)([^%)]+)(%))",
    function(prefix, value, suffix)
        -- Add tonumber() around the value if it might be a string
        return prefix .. " tonumber(" .. value .. ")" .. suffix
    end
)

-- Fix any other string format issues with positions
fixed_overlay = fixed_overlay:gsub(
    "(Drawing QR code at position: )([^%s]+),([^%s]+)",
    function(prefix, x, y)
        -- Ensure x and y are treated as numbers in string format
        return prefix .. "tonumber(" .. x .. "),tonumber(" .. y .. ")"
    end
)

-- Write the fixed files
local out_file = io.open("qrencode.lua", "w")
if not out_file then
    print("ERROR: Could not open qrencode.lua for writing")
    os.exit(1)
end
out_file:write(fixed_content)
out_file:close()
print("Fixed qrencode.lua")

local overlay_out_file = io.open("qrcode_overlay.lua", "w")
if not overlay_out_file then
    print("ERROR: Could not open qrcode_overlay.lua for writing")
    os.exit(1)
end
overlay_out_file:write(fixed_overlay)
overlay_out_file:close()
print("Fixed qrcode_overlay.lua")

print("Files fixed successfully!") 