#!/usr/bin/env lua

-- This script tests the fixed handle_remote_trigger function
-- to ensure it doesn't cause infinite recursion

-- Mock the required objects
_G.sys = {
    now = function() return os.time() end
}

_G.node = {
    event = function(name, callback) end
}

_G.debug_print = function(msg)
    print(msg)
end

local original_print = print
-- Capture print output for testing
local print_log = {}
_G.print = function(...)
    local args = {...}
    local msg = ""
    for i, v in ipairs(args) do
        if i > 1 then msg = msg .. "\t" end
        msg = msg .. tostring(v)
    end
    print_log[#print_log+1] = msg
    original_print(...)
end

-- Load the qrcode_overlay module
print("Loading qrcode_overlay.lua...")
local f = assert(loadfile("qrcode_overlay.lua"))
_G.qrcode_overlay = f()
assert(_G.qrcode_overlay, "Failed to load qrcode_overlay module")

-- Create a minimal page_source mock
local page_source = {
    find_by_remote = function(remote)
        print("Page source looking for remote trigger: " .. remote)
        if remote == "3" then
            return {
                { get_tiles = function() return {} end, 
                  get_duration = function() return 10 end,
                  is_fallback = false,
                  name = "QR Code Page" }
            }
        elseif remote == "4" then
            return {
                { get_tiles = function() return {} end, 
                  get_duration = function() return 10 end,
                  is_fallback = false,
                  name = "Info Page" }
            }
        else
            return nil
        end
    end
}

-- Create a minimal job_queue mock
local job_queue = {
    add = function(handler, starts, ends)
        print("Job added: " .. tostring(starts) .. " to " .. tostring(ends))
    end,
    flush = function()
        print("Job queue flushed")
    end
}

-- Create a scheduler function
local function Scheduler(page_source, job_queue)
    local function enqueue_interactive(pages)
        print("Enqueueing interactive pages: " .. #pages)
        for i, page in ipairs(pages) do
            print("  Page: " .. (page.name or "unnamed"))
        end
    end

    local function handle_remote_trigger(remote)
        print("Scheduler remote trigger received: " .. remote)
        
        -- Process normal page navigation
        local pages = page_source.find_by_remote(remote)
        if not pages then
            print("No pages found for remote trigger: " .. remote)
            return false
        end
        enqueue_interactive(pages)
        return true
    end

    return {
        handle_remote_trigger = handle_remote_trigger
    }
end

-- Create scheduler instance
_G.scheduler = Scheduler(page_source, job_queue)

-- Test normal execution (should work)
print("\n=== Testing remote trigger handling ===")
print("Testing remote trigger 3 (QR Code Page)...")
local result = _G.qrcode_overlay.handle_remote_trigger("3")
print("QR code handling returned: " .. tostring(result))

print("\nTesting remote trigger 4 (Info Page)...")
local result2 = _G.qrcode_overlay.handle_remote_trigger("4")
print("QR code handling returned: " .. tostring(result2))

print("\nTesting remote trigger 9 (Invalid trigger)...")
local result3 = _G.qrcode_overlay.handle_remote_trigger("9")
print("QR code handling returned: " .. tostring(result3))

print("\n=== Test completed successfully ===")
print("No infinite recursion detected.") 