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
    background_color = {0, 0, 0, 0.1},  -- Dark background with 40% opacity
    foreground_color = {0, 0, 0, 1},    -- Black QR code pixels
    border_size = 15,                   -- Size of the border around the QR code
    
    -- Title settings
    --[[ title_text = "Scan QR Code",        -- Text displayed above QR code
    title_height = 30,                  -- Height of the title area
    title_font_size = 24,               -- Font size for the title text
    title_color = {1, 1, 1, 1},         -- White text ]]
}
-- =============================================

-- Variables for QR code functionality
local show_qr_code = false
local qr_draw_function = nil
local qr_expiry_time = 0
local QR_DISPLAY_DURATION = 3600  -- Show QR code for 3600 seconds (1 hour) instead of 60 seconds
local PERMANENT_DISPLAY = false   -- Flag for permanent display (no expiration)
local current_trigger = nil       -- Track the current active trigger
local qrencode = nil  -- Will be initialized when needed

-- Debug variables for dimensions
local qr_debug = {
    matrix_width = 0,
    matrix_height = 0,
    pixel_width = 0,
    pixel_height = 0,
    total_width = 0,
    total_height = 0,
    last_position_x = 0,
    last_position_y = 0
}

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
    
    -- Configurable size settings
    local qr_size = QR_CONFIG.module_size
    local border = QR_CONFIG.border_size
    local title_height = QR_CONFIG.title_height
    local title_text = QR_CONFIG.title_text
    local title_font_size = QR_CONFIG.title_font_size
    local background_alpha = QR_CONFIG.background_color[4]
    
    -- Calculate dimensions
    local width = #qr_matrix[1] * qr_size
    local height = #qr_matrix * qr_size
    
    -- Update debug variables
    qr_debug.matrix_width = #qr_matrix[1]
    qr_debug.matrix_height = #qr_matrix
    qr_debug.pixel_width = width
    qr_debug.pixel_height = height
    qr_debug.total_width = width + (border * 2)
    qr_debug.total_height = height + (border * 2) + title_height
    
    debug_print("==== QR CODE DIMENSIONS ====")
    debug_print("Matrix size: " .. qr_debug.matrix_width .. "x" .. qr_debug.matrix_height .. " modules")
    debug_print("Module size: " .. qr_size .. " pixels")
    debug_print("QR code size: " .. width .. "x" .. height .. " pixels (without border)")
    debug_print("Border size: " .. border .. " pixels")
    debug_print("Title height: " .. title_height .. " pixels")
    debug_print("Total dimensions: " .. qr_debug.total_width .. "x" .. qr_debug.total_height .. " pixels (with border and title)")
    debug_print("===========================")

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
        return nil
    end
    
    debug_print("Created QR code textures successfully")

    return function(x, y)
        debug_print("Drawing QR code at position: " .. x .. "," .. y)
        
        -- Store position for debugging
        qr_debug.last_position_x = x
        qr_debug.last_position_y = y
        
        -- Calculate the area the QR code will occupy on screen
        local draw_area = {
            left = x - border,
            top = y - border - title_height,
            right = x + width + border,
            bottom = y + height + border
        }
        
        debug_print("QR code will occupy screen area from (" .. 
                   draw_area.left .. "," .. draw_area.top .. ") to (" .. 
                   draw_area.right .. "," .. draw_area.bottom .. ")")
        
        -- Draw semi-transparent background behind the QR code
        -- Draw background with extra space for title
        bg:draw(draw_area.left, draw_area.top, draw_area.right, draw_area.bottom)
        
        -- Draw white background for the QR code
        img:draw(x, y, x + width, y + height)
        
        -- Draw title text
        font:write(x + width/2 - (title_font_size * string.len(title_text)/4), 
                   y - title_height + 5, 
                   title_text, 
                   title_font_size, 
                   QR_CONFIG.title_color[1], QR_CONFIG.title_color[2], QR_CONFIG.title_color[3], QR_CONFIG.title_color[4])
        
        -- Position the QR code at (x, y)
        for i = 1, #qr_matrix do
            for j = 1, #qr_matrix[i] do
                if qr_matrix[i][j] == 1 then  -- Draw black square for '1'
                    black_pixel:draw(x + (j-1) * qr_size, y + (i-1) * qr_size, x + j * qr_size, y + i * qr_size)
                end
            end
        end
        
        debug_print("QR code drawing completed")
    end
end

-- Function to generate QR code and save it to a file
local function generate_qr_code_file(data)
    debug_print("Attempting to generate QR code for: " .. data)
    
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
            return false
        end
        
        -- Verify the module has the qrcode function
        if type(qrencode.qrcode) ~= "function" then
            debug_print("ERROR: qrencode module missing qrcode function")
            qrencode = nil
            return false
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
        return false
    end
    
    if not ok then
        debug_print("ERROR: QR code generation failed")
        return false
    end
    
    if not matrix then
        debug_print("ERROR: QR generation did not produce a matrix")
        return false
    end
    
    debug_print("QR matrix generated successfully, size: " .. #matrix .. "x" .. #matrix[1])
    
    -- Save the matrix directly as a Lua table - no file I/O needed
    -- Convert to a simple representation
    local qr_matrix = {}
    for y = 1, #matrix do
        qr_matrix[y] = {}
        for x = 1, #matrix[y] do
            qr_matrix[y][x] = matrix[y][x] > 0 and 1 or 0
        end
    end
    
    debug_print("Successfully created QR code matrix in memory")
    
    -- Draw the QR code directly without saving to a file
    qr_draw_function = convert_qr_to_image(qr_matrix)
    if qr_draw_function then
        debug_print("QR draw function created successfully")
        return true
    else
        debug_print("ERROR: Failed to create QR draw function")
        return false
    end
end

-- Function to handle remote trigger 3 and generate QR code
function M.handle_remote_trigger(data)
    debug_print("Handle remote trigger called with data: " .. tostring(data))
    
    -- Ensure we have a string value
    if type(data) ~= "string" then
        debug_print("Invalid trigger data type: " .. type(data))
        return false
    end
    
    -- Always hide QR code when switching to any trigger other than 3 or 3p
    if data ~= "3" and data ~= "3p" then
        debug_print("Trigger " .. data .. " received - hiding QR code")
        show_qr_code = false
        PERMANENT_DISPLAY = false
    end
    
    -- Update current trigger
    current_trigger = data
    debug_print("Current trigger set to: " .. current_trigger)
    
    if data == "3" then
        debug_print("Trigger 3 activated: Generating QR code")
        
        -- Generate a URL with current timestamp
        local timestamp = format_timestamp()
        local url = "http://activations.courtsidevideo.com?asset_id=12345&timestamp=" .. timestamp .. "&tile_id=7890"
        
        debug_print("Generated URL for QR code: " .. url)
        
        -- Generate QR code and save to file
        debug_print("Starting QR code generation process")
        local qr_generated = generate_qr_code_file(url)
        debug_print("QR code generation result: " .. tostring(qr_generated))
        
        if qr_generated then
            -- Set flag to show QR code
            show_qr_code = true
            PERMANENT_DISPLAY = true  -- Make it display permanently while on this trigger
            debug_print("Setting show_qr_code flag to true")
            
            -- Set expiry time (still needed as fallback)
            qr_expiry_time = sys.now() + QR_DISPLAY_DURATION
            debug_print("QR code ready to display permanently while on trigger 3")
            debug_print("QR code state: show_qr_code=" .. tostring(show_qr_code) .. ", qr_draw_function_exists=" .. tostring(qr_draw_function ~= nil))
            return true
        else
            debug_print("ERROR: Failed to generate QR code")
        end
    else
        debug_print("Trigger " .. data .. " is not handled by QR code module (QR code hidden)")
        -- QR code should already be hidden from our check at the top
        return false
    end
    
    return false
end

-- Function to check if QR code should be displayed
function M.show_qr()
    if show_qr_code and qr_draw_function ~= nil then
        debug_print("QR code is ready to be displayed")
        return true
    end
    debug_print("QR code not ready to be displayed. show_qr_code=" .. tostring(show_qr_code) .. 
                ", qr_draw_function=" .. tostring(qr_draw_function ~= nil))
    return false
end

-- Function to draw QR code at specified position
function M.draw_qr(x, y)
    debug_print("draw_qr called for position " .. x .. "," .. y)
    
    if not show_qr_code then
        debug_print("QR code not set to show")
        return false
    end
    
    debug_print("QR code is set to show")
    
    if not qr_draw_function then
        debug_print("ERROR: QR draw function is nil")
        return false
    end
    
    debug_print("QR draw function is available")
    
    local now = sys.now()
    if not PERMANENT_DISPLAY and now > qr_expiry_time then
        debug_print("QR code display time expired")
        show_qr_code = false
        return false
    else
        local remaining
        if PERMANENT_DISPLAY then
            remaining = "permanent"
        else
            remaining = math.floor(qr_expiry_time - now)
        end
        
        debug_print("==== QR CODE RENDERING INFO ====")
        debug_print("Position requested: " .. x .. "," .. y)
        debug_print("QR code matrix: " .. qr_debug.matrix_width .. "x" .. qr_debug.matrix_height .. " modules")
        debug_print("QR code pixel size: " .. qr_debug.pixel_width .. "x" .. qr_debug.pixel_height)
        debug_print("Total area with border: " .. qr_debug.total_width .. "x" .. qr_debug.total_height)
        debug_print("Expiry: " .. remaining .. (PERMANENT_DISPLAY and "" or " seconds"))
        debug_print("===============================")
        
        local success, err = pcall(function()
            qr_draw_function(x, y)
            return true
        end)
        
        if not success then
            debug_print("ERROR: Exception during QR drawing: " .. tostring(err))
            show_qr_code = false
            return false
        end
        
        debug_print("QR code drawn successfully")
        return true
    end
end

-- Function to update QR code appearance settings
-- This allows changing appearance settings at runtime without editing the files
function M.update_appearance(settings)
    debug_print("Updating QR code appearance settings")
    
    if type(settings) ~= "table" then
        debug_print("ERROR: Settings must be a table")
        return false
    end
    
    -- Update individual settings if provided
    if settings.module_size then
        QR_CONFIG.module_size = settings.module_size
        debug_print("Updated module_size to " .. settings.module_size)
    end
    
    if settings.background_color then
        QR_CONFIG.background_color = settings.background_color
        debug_print("Updated background_color")
    end
    
    if settings.foreground_color then
        QR_CONFIG.foreground_color = settings.foreground_color
        debug_print("Updated foreground_color")
    end
    
    if settings.border_size then
        QR_CONFIG.border_size = settings.border_size
        debug_print("Updated border_size to " .. settings.border_size)
    end
    
    if settings.title_text then
        QR_CONFIG.title_text = settings.title_text
        debug_print("Updated title_text to '" .. settings.title_text .. "'")
    end
    
    if settings.title_height then
        QR_CONFIG.title_height = settings.title_height
        debug_print("Updated title_height to " .. settings.title_height)
    end
    
    if settings.title_font_size then
        QR_CONFIG.title_font_size = settings.title_font_size
        debug_print("Updated title_font_size to " .. settings.title_font_size)
    end
    
    if settings.title_color then
        QR_CONFIG.title_color = settings.title_color
        debug_print("Updated title_color")
    end
    
    -- Regenerate QR code with new settings if we have an active QR code
    if show_qr_code and qr_draw_function then
        debug_print("Regenerating QR code with new appearance settings")
        -- We need to trigger a QR code regeneration to apply the new settings
        -- Use the current trigger value if available
        if current_trigger == "3" or current_trigger == "3p" then
            -- Re-trigger the QR code generation
            M.handle_remote_trigger(current_trigger)
        end
    end
    
    return true
end

-- Function to get current QR code status for debugging
function M.get_status()
    return {
        visible = show_qr_code,
        permanent = PERMANENT_DISPLAY,
        current_trigger = current_trigger,
        expiry_time = qr_expiry_time,
        remaining = qr_expiry_time > 0 and (qr_expiry_time - sys.now()) or 0,
        has_draw_function = qr_draw_function ~= nil,
        appearance = QR_CONFIG  -- Include appearance settings in status
    }
end

-- Function to get QR code dimensions
function M.get_dimensions()
    return {
        matrix_size = {
            width = qr_debug.matrix_width,
            height = qr_debug.matrix_height
        },
        pixel_size = {
            width = qr_debug.pixel_width,
            height = qr_debug.pixel_height
        },
        total_size = {
            width = qr_debug.total_width,
            height = qr_debug.total_height
        },
        last_position = {
            x = qr_debug.last_position_x,
            y = qr_debug.last_position_y
        },
        module_size = QR_CONFIG.module_size,
        border_size = QR_CONFIG.border_size,
        title_height = QR_CONFIG.title_height
    }
end

return M 