#!/usr/bin/env lua

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

print("Testing qrencode.lua loading with noglobals() active...")

-- Try to load the module
local success, result = pcall(function()
    return require("qrencode")
end)

if success then
    print("SUCCESS: qrencode module loaded successfully!")
    print("Module type:", type(result))
    print("Contains qrcode function:", type(result.qrcode) == "function")
    
    -- Try to generate a QR code
    local ok, matrix = result.qrcode("https://example.com")
    if ok then
        print("QR code generation successful!")
        print("Matrix size:", #matrix .. "x" .. #matrix[1])
    else
        print("QR code generation failed!")
    end
else
    print("FAILED: Could not load qrencode module:")
    print(result)
end 