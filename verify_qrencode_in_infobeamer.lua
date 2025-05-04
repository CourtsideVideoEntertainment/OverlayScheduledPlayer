#!/usr/bin/env lua

print("Verifying qrencode module in info-beamer environment...")

-- Define the globals that would normally be available in info-beamer
-- These are minimal implementations to simulate the info-beamer environment
local _G = _G
_G.sys = {
    now = function() 
        return os.time() 
    end,
    -- Other sys functions would be here in the real environment
}

_G.resource = {
    create_colored_texture = function(r, g, b, a)
        -- Ensure all parameters are numbers
        r = tonumber(r) or 0
        g = tonumber(g) or 0
        b = tonumber(b) or 0
        a = tonumber(a) or 1
        print(string.format("Creating texture with color: %.1f, %.1f, %.1f, %.1f", r, g, b, a))
        return {
            draw = function(self, x, y, w, h, alpha)
                -- Ensure all parameters are numbers
                x = tonumber(x) or 0
                y = tonumber(y) or 0
                w = tonumber(w) or 0
                h = tonumber(h) or 0
                alpha = tonumber(alpha) or 1.0
                print(string.format("Drawing texture at: %.1f, %.1f, %.1f, %.1f with alpha %.1f", x, y, w, h, alpha))
            end
        }
    end,
    -- Other resource functions would be here in the real environment
    load_font = function(font_path, size)
        print("Loading font: " .. font_path)
        return {
            write = function(self, x, y, text, size, r, g, b, a)
                -- Ensure all parameters are numbers
                x = tonumber(x) or 0
                y = tonumber(y) or 0
                size = tonumber(size) or 20
                r = tonumber(r) or 1
                g = tonumber(g) or 1
                b = tonumber(b) or 1
                a = tonumber(a) or 1
                print(string.format("Writing text '%s' at position %.1f,%.1f with size %.1f", text, x, y, size))
            end
        }
    end
}

-- Implement the noglobals function used by info-beamer
local allowed_globals = {}
for k, v in pairs(_G) do
    allowed_globals[k] = true
end

function _G.noglobals()
    local mt = getmetatable(_G) or {}
    mt.__newindex = function(t, k, v)
        if not allowed_globals[k] then
            error("attempt to set undeclared global: " .. tostring(k), 2)
        end
        rawset(t, k, v)
    end
    mt.__index = function(t, k)
        if not allowed_globals[k] then
            error("attempt to reference missing global: " .. tostring(k), 2)
        end
        return rawget(t, k)
    end
    setmetatable(_G, mt)
end

-- Activate noglobals() to simulate info-beamer environment
noglobals()

-- Test loading the qrencode module directly
print("Testing direct loading of qrencode module")
local status, qrencode = pcall(require, "qrencode")
if status then
    print("Successfully loaded qrencode module")
    if type(qrencode) == "table" then
        print("qrencode is a table as expected")
        if type(qrencode.qrcode) == "function" then
            print("qrcode function found in the module")
            
            -- Try generating a QR code
            local qr_status, qr_result = pcall(qrencode.qrcode, "http://test.com", "L", 0, 1)
            if qr_status then
                -- Check the type of the result (could be a matrix table or boolean)
                print("QR code generation call succeeded")
                if type(qr_result) == "table" then
                    print("QR code matrix generated successfully, size: " .. #qr_result .. "x" .. #qr_result[1])
                else
                    print("QR code generation result type: " .. type(qr_result) .. ", value: " .. tostring(qr_result))
                end
            else
                print("QR code generation failed: " .. tostring(qr_result))
            end
        else
            print("ERROR: qrcode function not found in the module")
        end
    else
        print("ERROR: qrencode module is not a table, it's a " .. type(qrencode))
    end
else
    print("ERROR: Failed to load qrencode module: " .. tostring(qrencode))
end

-- Now test loading the qrcode_overlay module which uses qrencode
print("\nTesting qrcode_overlay module which uses qrencode")
local status, qrcode_overlay = pcall(require, "qrcode_overlay")
if status then
    print("Successfully loaded qrcode_overlay module")
    
    -- Test the remote trigger handling
    print("Testing remote trigger for QR code")
    local trigger_result = qrcode_overlay.handle_remote_trigger("3")
    print("Remote trigger result: " .. tostring(trigger_result))
    
    -- Test drawing the QR code
    print("Testing QR code drawing")
    local pcall_status, qr_draw_result = pcall(function() 
        return qrcode_overlay.draw_qr(100, 100)
    end)
    
    if pcall_status then
        print("QR drawing call succeeded, result: " .. tostring(qr_draw_result))
    else
        print("ERROR: Exception during QR drawing: " .. tostring(qr_draw_result))
    end
else
    print("ERROR: Failed to load qrcode_overlay module: " .. tostring(qrcode_overlay))
end

print("\nVerification completed.") 