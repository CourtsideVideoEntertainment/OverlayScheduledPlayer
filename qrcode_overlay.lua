-- qrcode_overlay.lua
-- This module handles QR code generation and display for info-beamer

local M = {}

-- =============================================
-- QR CODE APPEARANCE CONFIGURATION
-- You can adjust these settings to customize the QR code appearance
-- =============================================
local QR_CONFIG = {
    -- QR code module size (a QR code is made up of small squares called modules)
    module_size = 5,  -- Size of each square module in pixels
    
    -- QR code appearance
    background_color = {0, 0, 0, 0.1},  -- Dark background with 10% opacity
    foreground_color = {0, 0, 0, 1},    -- Black QR code pixels
    border_size = 15,                   -- Size of the border around the QR code
    
    -- Title settings
    title_text = "",        -- Text displayed above QR code (REMOVED)
    title_height = 0,                  -- Height of the title area (REMOVED)
    title_font_size = 24,               -- Font size for the title text
    title_color = {1, 1, 1, 1},         -- White text
}
-- =============================================

-- Variables for QR code functionality
-- REMOVED Global state variables: show_qr_code, qr_draw_function, qr_expiry_time, 
-- PERMANENT_DISPLAY, current_trigger, current_setup_id_for_qr
local QR_DISPLAY_DURATION = 3600  -- Default duration (can be overridden by trigger type '3p')
local qrencode = nil  -- Will be initialized when needed

-- REMOVED Global qr_debug table. Dimensions will be returned per QR code.
-- local qr_debug = { ... }

-- Get the base directory path
local base_dir = "./"  -- Use relative path in the current directory

-- Print with timestamp to make debugging easier
local function debug_print(message)
    local timestamp = os.date("%H:%M:%S")
    print("[QR MODULE " .. timestamp .. "] " .. message)
end

-- Function to format timestamp without using os.date (which might not be available in info-beamer)
local function format_timestamp()
    local now = sys.now()
    local time = os.time() -- Still need to convert to unix timestamp
    
    -- Format manually without using os.date
    local timestamp = os.date("*t", time)
    return string.format("%02d%02d%02d%02d%02d", 
        timestamp.day, timestamp.month, timestamp.year % 100, timestamp.hour, timestamp.min)
end

-- Function to convert QR matrix to image (must be defined before generate_qr_code_file)
local function convert_qr_to_image(qr_matrix)
    debug_print("Converting QR matrix to drawable function")
    
    -- Configurable size settings (remains global via QR_CONFIG)
    local qr_size = QR_CONFIG.module_size
    local border = QR_CONFIG.border_size
    local title_height = QR_CONFIG.title_height
    local title_text = QR_CONFIG.title_text
    local title_font_size = QR_CONFIG.title_font_size
    local background_alpha = QR_CONFIG.background_color[4]
    
    -- Calculate dimensions for this specific QR code
    local matrix_w = #qr_matrix[1]
    local matrix_h = #qr_matrix
    local width = matrix_w * qr_size
    local height = matrix_h * qr_size
    local total_width = width + (border * 2)
    local total_height = height + (border * 2) + title_height
    
    -- Store calculated dimensions in a local table to be returned
    local dimensions = {
        matrix_width = matrix_w,
        matrix_height = matrix_h,
        pixel_width = width,
        pixel_height = height,
        total_width = total_width,
        total_height = total_height,
        module_size = qr_size, -- Include config values used
        border_size = border,
        title_height = title_height
    }
    
    debug_print("==== QR CODE DIMENSIONS (Instance) ====")
    debug_print("Matrix size: " .. dimensions.matrix_width .. "x" .. dimensions.matrix_height .. " modules")
    debug_print("Module size: " .. dimensions.module_size .. " pixels")
    debug_print("QR code size: " .. dimensions.pixel_width .. "x" .. dimensions.pixel_height .. " pixels (without border)")
    debug_print("Border size: " .. dimensions.border_size .. " pixels")
    debug_print("Title height: " .. dimensions.title_height .. " pixels")
    debug_print("Total dimensions: " .. dimensions.total_width .. "x" .. dimensions.total_height .. " pixels (with border and title)")
    debug_print("====================================")

    -- Create textures for QR code rendering
    local bg, img, black_pixel, font
    
    local success, err = pcall(function()
        -- Create a white background with black QR code
        bg = resource.create_colored_texture(QR_CONFIG.background_color[1], QR_CONFIG.background_color[2], QR_CONFIG.background_color[3], background_alpha)
        img = resource.create_colored_texture(1, 1, 1, 1)    -- White background
        black_pixel = resource.create_colored_texture(QR_CONFIG.foreground_color[1], QR_CONFIG.foreground_color[2], QR_CONFIG.foreground_color[3], 1)  -- Black pixel
        font = resource.load_font("default-font.ttf")
        return true
    end)
    
    if not success then
        debug_print("ERROR: Failed to create resources: " .. tostring(err))
        return nil, nil -- Return nil for both function and dimensions on error
    end
    
    debug_print("Created QR code textures successfully")

    -- Create the drawing function (closure)
    local draw_func = function(x, y)
        -- Note: This function now uses the 'dimensions' table captured from its parent scope
        -- instead of a global qr_debug table.
        debug_print("Drawing QR code instance at position: " .. x .. "," .. y)
        
        -- Calculate the area the QR code will occupy on screen
        local draw_area = {
            left = x - dimensions.border_size,
            top = y - dimensions.border_size - dimensions.title_height,
            right = x + dimensions.pixel_width + dimensions.border_size,
            bottom = y + dimensions.pixel_height + dimensions.border_size
        }
        
        debug_print("QR instance draw area: (" .. 
                   draw_area.left .. "," .. draw_area.top .. ") to (" .. 
                   draw_area.right .. "," .. draw_area.bottom .. ")")
        
        -- Draw semi-transparent background behind the QR code
        bg:draw(draw_area.left, draw_area.top, draw_area.right, draw_area.bottom)
        
        -- Draw white background for the QR code
        img:draw(x, y, x + dimensions.pixel_width, y + dimensions.pixel_height)
        
        -- Draw title text (if configured)
        if dimensions.title_height > 0 and title_text ~= "" then
            font:write(x + dimensions.pixel_width/2 - (title_font_size * string.len(title_text)/4), 
                       y - dimensions.title_height + 5, 
                       title_text, 
                       title_font_size, 
                       QR_CONFIG.title_color[1], QR_CONFIG.title_color[2], QR_CONFIG.title_color[3], QR_CONFIG.title_color[4])
        end

        -- Position the QR code at (x, y)
        for i = 1, dimensions.matrix_height do
            for j = 1, dimensions.matrix_width do
                if qr_matrix[i][j] == 1 then  -- Draw black square for '1'
                    black_pixel:draw(x + (j-1) * dimensions.module_size, y + (i-1) * dimensions.module_size, 
                                     x + j * dimensions.module_size, y + i * dimensions.module_size)
                end
            end
        end
        
        debug_print("QR code instance drawing completed")
    end

    -- Return the drawing function and the calculated dimensions
    return draw_func, dimensions
end

-- Function to generate QR code matrix and drawing details
local function generate_qr_details(data)
    debug_print("Attempting to generate QR details for: " .. data)
    
    -- Load the qrencode module if not already loaded
    if not qrencode then
        debug_print("Loading qrencode module")
        
        -- Try loading the module directly with require
        debug_print("Attempting to load qrencode with require")
        local success, result = pcall(function() return require("qrencode") end)
        
        if success and result then
            debug_print("Successfully loaded qrencode with require")
            qrencode = result
        else
            debug_print("Failed to load with require: " .. tostring(result))
            qrencode = nil
            return nil, { error = "Failed to load qrencode" }
        end
        
        -- Verify the module has the qrcode function
        if type(qrencode.qrcode) ~= "function" then
            debug_print("ERROR: qrencode module missing qrcode function")
            qrencode = nil
            return nil, { error = "qrencode module missing qrcode function" }
        end
        
        debug_print("qrencode module successfully loaded")
    end
    
    debug_print("Generating QR code using qrencode.qrcode")
    local ok, matrix
    local success, err = pcall(function()
        ok, matrix = qrencode.qrcode(data)
        return matrix
    end)
    
    if not success then
        debug_print("ERROR: Exception during QR code generation: " .. tostring(err))
        return nil, { error = "Exception during generation: " .. tostring(err) }
    end
    
    if not ok then
        debug_print("ERROR: QR code generation failed")
        return nil, { error = "qrencode.qrcode failed" }
    end
    
    if not matrix then
        debug_print("ERROR: QR generation did not produce a matrix")
        return nil, { error = "qrencode.qrcode returned no matrix" }
    end
    
    debug_print("QR matrix generated successfully, size: " .. #matrix .. "x" .. #matrix[1])
    
    -- Convert to simple 0/1 matrix
    local qr_matrix = {}
    for y = 1, #matrix do
        qr_matrix[y] = {}
        for x = 1, #matrix[y] do
            qr_matrix[y][x] = matrix[y][x] > 0 and 1 or 0
        end
    end
    
    debug_print("Successfully created QR code matrix in memory")
    
    -- Convert the matrix to a drawing function and get dimensions
    local draw_func, dimensions = convert_qr_to_image(qr_matrix)
    
    if draw_func and dimensions then
        debug_print("QR draw function created successfully")
        -- Return the function and dimensions
        return draw_func, dimensions
    else
        debug_print("ERROR: Failed to create QR draw function")
        return nil, { error = "Failed to convert matrix to image" }
    end
end

-- Function to handle remote trigger and generate QR code details
-- Returns a table with { draw_function, dimensions, expiry_time, permanent_display, generated_url } or nil on error
function M.handle_remote_trigger(trigger_data, setup_id)
    debug_print("setup_id: " .. tostring(setup_id))
    debug_print("Handle remote trigger called with trigger_data: " .. tostring(trigger_data) .. " and setup_id: " .. tostring(setup_id))
    
    -- Ensure we have a string value for trigger_data
    if type(trigger_data) ~= "string" then
        debug_print("Invalid trigger data type: " .. type(trigger_data))
        return nil -- Indicate error
    end
    
    -- Determine QR code content and properties based on trigger_data
    -- We only generate for specific triggers like "3" or "3p" or potentially others if defined later
    -- The calling code (node.lua) should handle hiding for other triggers.
    
    local is_permanent = false
    local url_asset_id = ""
    
    if trigger_data == "3p" then
        debug_print("Trigger '3p' activated: Generating permanent QR code")
        is_permanent = true
        url_asset_id = "3" -- Use "3" as asset_id for "3p" trigger
    elseif trigger_data == "3" then
        debug_print("Trigger '3' activated: Generating timed QR code")
        is_permanent = false
        url_asset_id = "3"
    else
        -- If the trigger isn't one that generates a QR code, return nil.
        -- The caller (node.lua) decides what to do (e.g., hide the relevant QR instance).
        debug_print("Trigger '" .. trigger_data .. "' does not generate a QR code in this module.")
        return nil 
    end
        
    -- Use the passed setup_id or fallback
    local device_id = setup_id
    if device_id and device_id ~= "UNKNOWN_SETUP" and device_id ~= "" then -- Also check for empty string
        debug_print("Using provided setup_id: " .. device_id)
    else
        device_id = "FALLBACK_DEVICE_ID" -- Use a fallback if setup_id is missing or default
        debug_print("setup_id missing or default, using fallback: " .. device_id)
    end

    -- Generate a URL with current timestamp and device_id
    local timestamp = format_timestamp()
    local url = "http://18.234.225.180/?asset_id=" .. url_asset_id .. "&timestamp=" .. timestamp .. "&device_id=" .. device_id
    
    debug_print("Generated URL for QR code: " .. url)
    
    -- Generate QR code drawing function and dimensions
    debug_print("Starting QR details generation process for URL")
    local draw_func, dimensions = generate_qr_details(url)
    
    if draw_func and dimensions then
        debug_print("QR details generation successful.")
        
        -- Calculate expiry time only if not permanent
        local expiry_time = 0
        if not is_permanent then
            expiry_time = sys.now() + QR_DISPLAY_DURATION
            debug_print("QR code expiry set for trigger " .. trigger_data)
        end

        -- Return the details package
        return {
            draw_function = draw_func,
            dimensions = dimensions,
            expiry_time = expiry_time,
            permanent_display = is_permanent,
            generated_url = url -- Included for caller's reference/logging
        }
    else
        debug_print("ERROR: Failed to generate QR details. Error info:", dimensions and dimensions.error or "Unknown")
        -- Return nil to indicate failure
        return nil
    end
end

-- REMOVED M.show_qr() - Visibility is managed by the caller (node.lua)

-- Function to draw a specific QR code instance at specified position
-- Takes the details package returned by handle_remote_trigger
-- Returns true if drawn, false if expired or error.
function M.draw_qr(draw_details, x, y, current_time)
    debug_print("draw_qr instance called for position " .. x .. "," .. y)
    
    if not draw_details or type(draw_details) ~= "table" or not draw_details.draw_function then
        debug_print("ERROR: Invalid or missing draw_details provided to draw_qr")
        return false
    end
    
    -- Check expiry
    if not draw_details.permanent_display and draw_details.expiry_time > 0 and current_time > draw_details.expiry_time then
        local remaining = math.floor(draw_details.expiry_time - current_time)
        debug_print("QR instance display time expired (" .. remaining .. "s ago)")
        return false -- Indicate it expired
    end

    local remaining_str = "permanent"
    if not draw_details.permanent_display then
        remaining_str = math.floor(draw_details.expiry_time - current_time) .. " seconds remaining"
    end
    debug_print("Attempting to draw QR instance. Expiry: " .. remaining_str)

    -- Call the specific draw function for this instance
    local success, err = pcall(function()
        draw_details.draw_function(x, y)
        return true
    end)
    
    if not success then
        debug_print("ERROR: Exception during QR instance drawing: " .. tostring(err))
        return false
    end
    
    debug_print("QR instance drawn successfully")
    return true
end

-- Function to update QR code appearance settings
-- This modifies the global QR_CONFIG used by future generations.
-- Returns true if settings might require regeneration, false otherwise.
function M.update_appearance(settings)
    debug_print("Updating global QR code appearance settings")
    
    if type(settings) ~= "table" then
        debug_print("ERROR: Settings must be a table")
        return false
    end
    
    local needs_regeneration = false -- Flag to track if regeneration is needed

    -- Update individual settings if provided
    if settings.module_size and QR_CONFIG.module_size ~= settings.module_size then
        QR_CONFIG.module_size = settings.module_size
        debug_print("Updated module_size to " .. settings.module_size)
        needs_regeneration = true
    end
    
    if settings.background_color and QR_CONFIG.background_color ~= settings.background_color then
        QR_CONFIG.background_color = settings.background_color
        debug_print("Updated background_color")
        needs_regeneration = true
    end
    
    if settings.foreground_color and QR_CONFIG.foreground_color ~= settings.foreground_color then
        QR_CONFIG.foreground_color = settings.foreground_color
        debug_print("Updated foreground_color")
        needs_regeneration = true
    end
    
    if settings.border_size and QR_CONFIG.border_size ~= settings.border_size then
        QR_CONFIG.border_size = settings.border_size
        debug_print("Updated border_size to " .. settings.border_size)
        needs_regeneration = true
    end
    
    -- Title changes only need regeneration if they affect layout (height)
    if settings.title_text and QR_CONFIG.title_text ~= settings.title_text then
        QR_CONFIG.title_text = settings.title_text
        debug_print("Updated title_text to '" .. settings.title_text .. "'")
        -- No regeneration needed unless title_height changes
    end
    
    if settings.title_height and QR_CONFIG.title_height ~= settings.title_height then
        QR_CONFIG.title_height = settings.title_height
        debug_print("Updated title_height to " .. settings.title_height)
        needs_regeneration = true
    end
    
    if settings.title_font_size and QR_CONFIG.title_font_size ~= settings.title_font_size then
        QR_CONFIG.title_font_size = settings.title_font_size
        debug_print("Updated title_font_size to " .. settings.title_font_size)
        -- No regeneration needed unless title_height changes
    end
    
    if settings.title_color and QR_CONFIG.title_color ~= settings.title_color then
        QR_CONFIG.title_color = settings.title_color
        debug_print("Updated title_color")
        -- No regeneration needed
    end
    
    -- Regenerate QR code with new settings if we have an active QR code and changes were made
    -- REMOVED: Regeneration logic is now handled by the caller (node.lua)
    -- if needs_regeneration and show_qr_code and (current_trigger == "3" or current_trigger == "3p") then ...

    debug_print("Global QR appearance config updated.")
    
    -- Return the flag indicating if changes might require regeneration
    return needs_regeneration 
end

-- REMOVED M.get_status() - Status is managed per-instance by the caller (node.lua)

-- Function to get *potential* QR code dimensions based on current global config
-- Note: Actual dimensions depend on data, this provides an estimate based on config only.
-- This might not be very useful if matrix size varies a lot.
function M.get_potential_dimensions()
     -- For estimation, maybe assume a typical matrix size (e.g., 25x25 for simple URLs)
     local est_matrix_w, est_matrix_h = 25, 25 
     local qr_size = QR_CONFIG.module_size
     local border = QR_CONFIG.border_size
     local title_height = QR_CONFIG.title_height

     local width = est_matrix_w * qr_size
     local height = est_matrix_h * qr_size
     local total_width = width + (border * 2)
     local total_height = height + (border * 2) + title_height

    return {
        estimated_total_size = {
            width = total_width,
            height = total_height
        },
        module_size = qr_size,
        border_size = border,
        title_height = title_height
    }
end

return M 