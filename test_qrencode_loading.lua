-- Test script to check if qrencode.lua can be loaded properly
print("Starting qrencode loading test...")

-- Try to load the qrencode.lua file directly using io.open
local file = io.open("qrencode.lua", "r")
if not file then
    print("ERROR: Could not open qrencode.lua file with io.open")
else
    print("SUCCESS: qrencode.lua file opened successfully with io.open")
    local content = file:read("*all")
    file:close()
    print("qrencode.lua file size: " .. #content .. " bytes")
    
    -- Try to load it as Lua code
    print("Attempting to load qrencode.lua as Lua code with load()")
    local chunk, err = load(content, "qrencode", "t", _G)
    if not chunk then
        print("ERROR: Failed to parse qrencode.lua: " .. tostring(err))
    else
        print("SUCCESS: qrencode.lua parsed successfully")
        
        -- Try to execute the module
        print("Attempting to execute qrencode module")
        local status, module = pcall(chunk)
        if not status then
            print("ERROR: Failed to execute qrencode module: " .. tostring(module))
        else
            print("SUCCESS: qrencode module executed successfully")
            
            -- Check if qrcode function exists
            if type(module) ~= "table" then
                print("ERROR: qrencode module did not return a table, got: " .. type(module))
            elseif type(module.qrcode) ~= "function" then
                print("ERROR: qrencode module does not have a qrcode function")
            else
                print("SUCCESS: qrencode.qrcode function found!")
                
                -- Try calling the qrcode function
                print("Testing qrcode() function with a sample URL")
                local status, result = pcall(function()
                    return module.qrcode("http://test.com")
                end)
                
                if not status then
                    print("ERROR: Failed to call qrcode function: " .. tostring(result))
                else
                    print("SUCCESS: qrcode function executed successfully")
                    print("qrcode result type: " .. type(result))
                end
            end
        end
    end
end

print("qrencode loading test completed") 