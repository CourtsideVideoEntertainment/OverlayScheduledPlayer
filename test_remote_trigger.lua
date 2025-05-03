#!/usr/bin/env lua
-- Test script to verify remote trigger functionality

print("Starting remote trigger test...")

-- Mock the necessary info-beamer environment
_G.sys = {
    now = function() return os.time() end
}

_G.resource = {
    create_colored_texture = function(r, g, b, a)
        print("Creating texture with color:", r, g, b, a)
        return {
            draw = function(self, x1, y1, x2, y2, alpha)
                print(string.format("Drawing texture at: %.1f, %.1f, %.1f, %.1f with alpha %.1f", x1, y1, x2, y2, alpha or 1.0))
                return true
            end
        }
    end,
    load_image = function(opts)
        print("Loading image:", opts.file)
        return {
            draw = function(self, x1, y1, x2, y2, alpha)
                print(string.format("Drawing image at: %.1f, %.1f, %.1f, %.1f with alpha %.1f", x1, y1, x2, y2, alpha or 1.0))
                return true
            end
        }
    end,
    load_font = function(font)
        print("Loading font:", font)
        return {
            write = function(self, x, y, text, size, r, g, b, a)
                print(string.format("Writing text '%s' at position %.1f,%.1f with size %.1f", text, x, y, size))
                return true
            end
        }
    end,
    open_file = function(filename)
        print("Opening file:", filename)
        return filename
    end
}

-- Mock the scheduler functions to test remote triggers
_G.scheduler = {
    schedules = {},
    active_page = nil,
    handle_remote_trigger = function(data)
        print("Scheduler received remote trigger:", data)
        
        -- Find pages associated with this trigger
        local found_pages = {}
        for _, schedule in ipairs(_G.scheduler.schedules) do
            for _, page in ipairs(schedule.pages) do
                if page.interaction.key == 'remote' and page.interaction.remote == data then
                    print("Found matching page:", page.name)
                    table.insert(found_pages, page)
                end
            end
        end
        
        if #found_pages > 0 then
            _G.scheduler.active_page = found_pages[1]
            print("Switched to page:", _G.scheduler.active_page.name)
            return true
        else
            print("No matching page found for trigger:", data)
            return false
        end
    end
}

-- Load the qrcode_overlay module
print("Loading qrcode_overlay module...")
local ok, qrcode_overlay = pcall(function() return require "qrcode_overlay" end)
if not ok then
    print("Error loading qrcode_overlay:", qrcode_overlay)
    return
end
print("qrcode_overlay module loaded successfully")

-- Set up test schedules
_G.scheduler.schedules = {
    {
        name = "Main Schedule",
        pages = {
            {
                name = "Default Page",
                interaction = { key = "none" }
            },
            {
                name = "QR Code Page",
                interaction = { key = "remote", remote = "3" }
            },
            {
                name = "Info Page",
                interaction = { key = "remote", remote = "4" }
            }
        }
    }
}

-- Test QR code trigger
print("\nTesting remote trigger 3 (QR Code)...")

-- First, test the QR code module's handling
local qr_result = qrcode_overlay.handle_remote_trigger("3")
print("QR code module result:", qr_result)

-- Then, test the scheduler's handling
local scheduler_result = _G.scheduler.handle_remote_trigger("3")
print("Scheduler result:", scheduler_result)
print("Active page after trigger 3:", _G.scheduler.active_page and _G.scheduler.active_page.name or "None")

-- Test another trigger
print("\nTesting remote trigger 4 (Info Page)...")
local scheduler_result2 = _G.scheduler.handle_remote_trigger("4")
print("Scheduler result:", scheduler_result2)
print("Active page after trigger 4:", _G.scheduler.active_page and _G.scheduler.active_page.name or "None")

-- Test a non-existent trigger
print("\nTesting remote trigger 9 (non-existent)...")
local scheduler_result3 = _G.scheduler.handle_remote_trigger("9")
print("Scheduler result:", scheduler_result3)
print("Active page after trigger 9:", _G.scheduler.active_page and _G.scheduler.active_page.name or "None")

print("\nRemote trigger test completed") 