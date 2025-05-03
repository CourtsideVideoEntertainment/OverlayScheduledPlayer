-- qrcode_overlay.lua
-- This module handles QR code generation and display for info-beamer

local M = {}

-- Variables for QR code functionality
local show_qr_code = false
local qr_draw_function = nil
local qr_expiry_time = 0
local QR_DISPLAY_DURATION = 60  -- Show QR code for 60 seconds
local qrencode = nil  -- Will be initialized when needed

-- Get the base directory path
local base_dir = "./"  -- Use relative path in the current directory

-- Print with timestamp to make debugging easier
local function debug_print(message)
    local timestamp = os.date("%H:%M:%S")
    print("[QR MODULE " .. timestamp .. "] " .. message)
end

-- Function to format current time as DDMMYYHHMM using info-beamer's time functions
local function format_timestamp()
    -- Use sys.now() instead of os.date
    local now = sys.now()
    local time = os.time() -- Still need to convert to unix timestamp
    
    -- Format manually without using os.date
    local timestamp = os.date("*t", time)
    return string.format("%02d%02d%02d%02d%02d", 
        timestamp.day, timestamp.month, timestamp.year % 100, timestamp.hour, timestamp.min)
end

-- Function to generate QR code and save it to a file
local function generate_qr_code_file(data)
    debug_print("Attempting to generate QR code for: " .. data)
    
    -- Load the qrencode module if not already loaded
    if not qrencode then
        debug_print("Loading qrencode module")
        
        local file, err = io.open(base_dir .. "qrencode.lua", "r")
        if not file then
            debug_print("ERROR: Could not open qrencode.lua file: " .. tostring(err))
            return false
        end
        
        debug_print("Reading qrencode.lua file content")
        local content = file:read("*all")
        file:close()
        
        if not content or #content == 0 then
            debug_print("ERROR: qrencode.lua file is empty or couldn't be read")
            return false
        end
        
        debug_print("File size is " .. #content .. " bytes")
        
        -- Try loading the module directly with require
        debug_print("Attempting to load qrencode with require")
        local success, module = pcall(function() return require("qrencode") end)
        
        if success and module then
            debug_print("Successfully loaded qrencode with require")
            qrencode = module
        else
            debug_print("Failed to load with require: " .. tostring(module))
            
            -- Fall back to parse manually with load()
            debug_print("Parsing qrencode.lua with load()")
            local chunk, err = load(content, "qrencode", "t", _G)
            if not chunk then
                debug_print("ERROR: Failed to parse qrencode.lua: " .. tostring(err))
                return false
            end
            
            debug_print("Executing qrencode module")
            local ok, module_result = pcall(chunk)
            if not ok then
                debug_print("ERROR: Failed to execute qrencode module: " .. tostring(module_result))
                return false
            end
            
            qrencode = module_result
            
            if not qrencode then
                debug_print("ERROR: qrencode module loader returned nil")
                return false
            end
            
            debug_print("Loaded qrencode module, type: " .. type(qrencode))
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
    
    local filepath = base_dir .. "qr_matrix.txt"
    debug_print("Writing QR matrix to file: " .. filepath)
    
    local file, err = io.open(filepath, "w")
    if not file then
        debug_print("ERROR: Failed to open file for writing: " .. filepath .. " - " .. tostring(err))
        return false
    end
    
    for y = 1, #matrix do
        local row = ""
        for x = 1, #matrix[y] do
            row = row .. (matrix[y][x] > 0 and "1" or "0")
        end
        file:write(row .. "\n")
    end
    file:close()
    
    debug_print("Successfully saved QR code matrix to " .. filepath)
    return true
end

-- Function to read QR matrix from file
local function read_qr_matrix(file_path)
    debug_print("Reading QR matrix from file: " .. file_path)
    
    local qr_matrix = {}
    local file, err = io.open(file_path, "r")
    if not file then
        debug_print("ERROR: Failed to open QR matrix file: " .. file_path .. " - " .. tostring(err))
        return nil
    end

    for line in file:lines() do
        local row = {}
        for char in line:gmatch(".") do
            table.insert(row, char == "1" and 1 or 0)  -- Convert '1' to 1 and '0' to 0
        end
        table.insert(qr_matrix, row)
    end
    file:close()
    
    if #qr_matrix == 0 then
        debug_print("ERROR: QR matrix is empty")
        return nil
    end
    
    debug_print("Successfully read QR matrix, size: " .. #qr_matrix .. "x" .. #qr_matrix[1])
    return qr_matrix
end

-- Function to convert ASCII QR matrix to image
local function convert_qr_to_image(qr_matrix)
    debug_print("Converting QR matrix to drawable function")
    
    -- Increase the size for better visibility
    local qr_size = 20  -- Increased from 10 to 20 for better visibility
    local width = #qr_matrix[1] * qr_size
    local height = #qr_matrix * qr_size
    
    debug_print("QR image dimensions: " .. width .. "x" .. height)

    -- Create textures for QR code rendering
    local bg, img, black_pixel, font
    
    local success, err = pcall(function()
        -- Create a white background with black QR code
        bg = resource.create_colored_texture(0, 0, 0, 0.7)  -- Semi-transparent dark background
        img = resource.create_colored_texture(1, 1, 1, 1)    -- White background
        black_pixel = resource.create_colored_texture(0, 0, 0, 1)  -- Black pixel
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
        
        -- Draw semi-transparent background behind the QR code
        local border = 40
        local title_height = 60
        
        -- Draw background with extra space for title
        bg:draw(x - border, y - border - title_height, x + width + border, y + height + border)
        
        -- Draw white background for the QR code
        img:draw(x, y, x + width, y + height)
        
        -- Draw title text
        font:write(x + width/2 - 100, y - title_height + 10, "Scan QR Code", 36, 1, 1, 1, 1)
        
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

-- Function to handle remote trigger 3 and generate QR code
function M.handle_remote_trigger(data)
    debug_print("Handle remote trigger called with data: " .. tostring(data))
    
    -- Ensure we have a string value
    if type(data) ~= "string" then
        debug_print("Invalid trigger data type: " .. type(data))
        return false
    end
    
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
            -- Read the QR matrix
            debug_print("Starting QR matrix reading")
            local qr_matrix = read_qr_matrix(base_dir .. "qr_matrix.txt")
            debug_print("QR matrix reading result: " .. tostring(qr_matrix ~= nil))
            
            if qr_matrix then
                -- Convert to drawing function
                debug_print("Creating QR draw function")
                qr_draw_function = convert_qr_to_image(qr_matrix)
                debug_print("QR draw function created: " .. tostring(qr_draw_function ~= nil))
                
                if qr_draw_function then
                    -- Set flag to show QR code
                    show_qr_code = true
                    debug_print("Setting show_qr_code flag to true")
                    
                    -- Set expiry time
                    qr_expiry_time = sys.now() + QR_DISPLAY_DURATION
                    debug_print("QR code ready to display for " .. QR_DISPLAY_DURATION .. " seconds")
                    debug_print("QR code state: show_qr_code=" .. tostring(show_qr_code) .. ", qr_draw_function_exists=" .. tostring(qr_draw_function ~= nil))
                    return true
                else
                    debug_print("ERROR: Failed to create QR draw function")
                end
            else
                debug_print("ERROR: Failed to read QR matrix")
            end
        else
            debug_print("ERROR: Failed to generate QR code file")
        end
    else
        debug_print("Trigger " .. data .. " is not handled by QR code module")
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
    if now > qr_expiry_time then
        debug_print("QR code display time expired")
        show_qr_code = false
        return false
    else
        local remaining = math.floor(qr_expiry_time - now)
        debug_print("Drawing QR code at position: " .. x .. "," .. y .. " - Expires in: " .. remaining .. " seconds")
        
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

return M 