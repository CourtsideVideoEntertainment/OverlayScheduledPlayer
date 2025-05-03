#!/usr/bin/env lua
-- This is a test script to specifically debug why trigger 3 isn't working while other triggers are

print("Starting QR code trigger issue test...")

-- Set up a more comprehensive mocking of the info-beamer environment
_G.sys = {
    now = function() return os.time() end
}

_G.node = {
    event = function(name, callback) end,
    alias = function() end,
    dispatch = function() end,
    render = function() end,
    gc = function() end
}

_G.gl = {
    setup = function() end,
    clear = function() end,
    translate = function() end,
    rotate = function() end,
    pushMatrix = function() end, 
    popMatrix = function() end
}

_G.resource = {
    create_colored_texture = function(r, g, b, a)
        print("Creating texture with color:", r, g, b, a)
        return {
            draw = function(self, x1, y1, x2, y2, alpha)
                print(string.format("Drawing texture at: %.1f, %.1f, %.1f, %.1f with alpha %.1f", x1, y1, x2, y2, alpha or 1.0))
                return self
            end,
            dispose = function() end
        }
    end,
    load_image = function(opts)
        print("Loading image:", opts.file)
        return {
            draw = function(self, x1, y1, x2, y2, alpha)
                print(string.format("Drawing image at: %.1f, %.1f, %.1f, %.1f with alpha %.1f", x1, y1, x2, y2, alpha or 1.0))
                return self
            end,
            dispose = function() end
        }
    end,
    load_font = function(font)
        print("Loading font:", font)
        return {
            write = function(self, x, y, text, size, r, g, b, a)
                print(string.format("Writing text '%s' at position %.1f,%.1f with size %.1f", text, x, y, size))
                return true
            end,
            width = function() return 100 end
        }
    end,
    open_file = function(filename)
        print("Opening file:", filename)
        return filename
    end,
    create_shader = function() 
        return {
            use = function() end,
            deactivate = function() end
        }
    end
}

_G.util = {
    no_globals = function() end,
    data_mapper = function() end,
    draw_correct = function() end,
    json_watch = function() end
}

-- Load qrcode_overlay.lua
print("Loading qrcode_overlay module...")
local success, qrcode_overlay = pcall(function() 
    dofile("qrcode_overlay.lua")
    return require("qrcode_overlay")
end)

if not success then
    print("Error loading qrcode_overlay module:", qrcode_overlay)
    os.exit(1)
end

print("Successfully loaded qrcode_overlay module")

-- Create a detailed mock of the node.lua environment
local page_source = {
    find_by_remote = function(remote)
        print("find_by_remote called with:", remote)
        if remote == "3" then
            print("Found page for remote trigger 3 (QR Code Page)")
            return {
                { 
                    get_tiles = function() return {} end, 
                    get_duration = function() return 10 end,
                    is_fallback = false,
                    name = "QR Code Page" 
                }
            }
        elseif remote == "4" then
            print("Found page for remote trigger 4 (Info Page)")
            return {
                { 
                    get_tiles = function() return {} end, 
                    get_duration = function() return 10 end,
                    is_fallback = false,
                    name = "Info Page" 
                }
            }
        else
            print("No page found for remote trigger", remote)
            return nil
        end
    end
}

local job_queue = {
    add = function(handler, starts, ends)
        print(string.format("Job added from %.2f to %.2f", starts, ends))
    end,
    flush = function()
        print("Job queue flushed")
    end,
    tick = function() end
}

-- Create a custom test scheduler that logs all operations
local function Scheduler(page_source, job_queue)
    local function enqueue_interactive(pages)
        print("enqueue_interactive called with", #pages, "pages")
        for i, page in ipairs(pages) do
            print("  Page:", page.name)
        end
    end

    local function reset_scheduler()
        print("reset_scheduler called")
        job_queue.flush()
    end

    local function handle_remote_trigger(remote)
        print("handle_remote_trigger called with:", remote)
        
        -- Process normal page navigation
        local pages = page_source.find_by_remote(remote)
        if not pages then
            print("No pages found for remote trigger:", remote)
            return false
        end
        
        print("Before enqueueing pages")
        reset_scheduler()
        enqueue_interactive(pages)
        print("After enqueueing pages")
        return true
    end

    return {
        handle_remote_trigger = handle_remote_trigger
    }
end

-- Set up the environment
_G.scheduler = Scheduler(page_source, job_queue)

-- Test trigger 3 and QR code generation
print("\n=== Testing normal trigger 3 (should work but doesn't in production) ===")
print("Testing qrcode_overlay.handle_remote_trigger with 3...")
local qr_result = qrcode_overlay.handle_remote_trigger("3")
print("QR code module result:", qr_result)

-- Test directly calling scheduler's handle_remote_trigger
print("\nTesting scheduler.handle_remote_trigger with 3...")
local scheduler_result = _G.scheduler.handle_remote_trigger("3")
print("Scheduler result:", scheduler_result)

-- Compare with trigger 4 which works
print("\n=== Testing trigger 4 (works in production) ===")
local scheduler_result2 = _G.scheduler.handle_remote_trigger("4")
print("Scheduler result for trigger 4:", scheduler_result2)

-- Now let's test the interaction between qrcode_overlay and scheduler
print("\n=== Testing combined flow with node.lua remote/trigger handler ===")
local function simulate_remote_trigger_handler(data)
    print("Simulating node.lua remote/trigger handler with data:", data)
    
    -- Call QR code module first (like in node.lua)
    print("Calling qrcode_overlay.handle_remote_trigger")
    local qr_result = qrcode_overlay.handle_remote_trigger(data)
    print("QR code handling result:", qr_result)
    
    -- Call scheduler handler (like in node.lua)
    print("Calling scheduler.handle_remote_trigger")
    local scheduler_result = _G.scheduler.handle_remote_trigger(data)
    print("Scheduler result:", scheduler_result)
    
    return scheduler_result
end

print("\nTesting trigger 3 with combined flow...")
local combined_result_3 = simulate_remote_trigger_handler("3")
print("Combined result for trigger 3:", combined_result_3)

print("\nTesting trigger 4 with combined flow...")
local combined_result_4 = simulate_remote_trigger_handler("4")
print("Combined result for trigger 4:", combined_result_4)

-- Test QR drawing functionality
print("\n=== Testing QR code drawing ===")
local draw_result = qrcode_overlay.draw_qr(100, 100)
print("QR code drawing result:", draw_result)

print("\n=== Verifying QR code display flag ===")
local show_result = qrcode_overlay.show_qr()
print("show_qr() result:", show_result)

print("\nQR code trigger issue test completed") 