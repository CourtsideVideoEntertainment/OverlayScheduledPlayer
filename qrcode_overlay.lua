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
    print("DEBUG: Attempting to generate QR code for: " .. data)
    
    -- Load the qrencode module if not already loaded
    if not qrencode then
        print("DEBUG: Loading qrencode module")
        
        -- Safety catch for all operations
        local status, result = pcall(function()
            -- Try to load using standard io instead of resource functions
            print("DEBUG: Opening qrencode.lua file with io.open")
            local file = io.open(base_dir .. "qrencode.lua", "r")
            
            if not file then
                print("ERROR: Could not open qrencode.lua file with io.open")
                return false
            end
            
            print("DEBUG: Reading qrencode.lua file content")
            local content = file:read("*all")
            file:close()
            
            if not content or #content == 0 then
                print("ERROR: qrencode.lua file is empty or couldn't be read")
                return false
            end
            
            print("DEBUG: File size is " .. #content .. " bytes")
            
            -- Try using Lua's native load function instead of loadstring
            print("DEBUG: Parsing qrencode.lua with load()")
            print("DEBUG: Content type before load: " .. type(content))
            
            local chunk, err = load(content, "qrencode", "t", _G)
            if not chunk then
                print("ERROR: Failed to parse qrencode.lua: " .. tostring(err))
                print("ERROR DETAILS: Error type: " .. type(err))
                return false
            else
                print("DEBUG: Chunk type after load: " .. type(chunk))
            end
            
            print("DEBUG: Executing qrencode module")
            local module_ok, module = pcall(chunk)
            if not module_ok then
                print("ERROR: Failed to execute qrencode chunk: " .. tostring(module))
                print("ERROR DETAILS: Error type: " .. type(module))
                return false
            else
                print("DEBUG: Module execution result type: " .. type(module))
            end
            
            if not module then
                print("ERROR: qrencode module loader returned nil")
                return false
            end
            
            if type(module) ~= "table" then
                print("ERROR: qrencode module did not return a table, got: " .. type(module))
                print("ERROR DETAILS: Module contents: " .. tostring(module))
                return false
            end
            
            if type(module.qrcode) ~= "function" then
                print("ERROR: qrencode module missing qrcode function")
                print("ERROR DETAILS: Module keys: ")
                for k, v in pairs(module) do
                    print("  - " .. k .. ": " .. type(v))
                end
                return false
            end
            
            print("DEBUG: qrencode module loaded successfully")
            return module
        end)
        
        if not status then
            print("ERROR: Exception during qrencode module loading: " .. tostring(result))
            print("ERROR DETAILS: Traceback: " .. debug.traceback())
            return false
        end
        
        qrencode = result
        
        if not qrencode then
            print("ERROR: Failed to load qrencode module")
            return false
        end
        
        print("DEBUG: Successfully loaded qrencode module")
    end
    
    print("DEBUG: Generating QR code using qrencode.qrcode")
    local status, result = pcall(function()
        local ok, matrix = qrencode.qrcode(data)
        print("DEBUG: qrcode() call result: " .. tostring(ok) .. ", matrix type: " .. type(matrix))
        if not ok then
            print("ERROR: QR code generation failed:", matrix)
            return nil
        end
        return matrix
    end)
    
    if not status then
        print("ERROR: Exception during QR code generation: " .. tostring(result))
        print("ERROR DETAILS: Traceback: " .. debug.traceback())
        return false
    end
    
    local matrix = result
    if not matrix then
        print("ERROR: QR generation did not produce a matrix")
        return false
    end
    
    print("DEBUG: QR matrix generated successfully, size: " .. #matrix .. "x" .. #matrix[1])
    
    local filepath = base_dir .. "qr_matrix.txt"
    print("DEBUG: Writing QR matrix to file: " .. filepath)
    
    local status, err = pcall(function()
        local file = io.open(filepath, "w")
        if not file then
            print("ERROR: Failed to open file for writing: " .. filepath)
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
        return true
    end)
    
    if not status then
        print("ERROR: Exception during file writing: " .. tostring(err))
        print("ERROR DETAILS: Traceback: " .. debug.traceback())
        return false
    end
    
    print("DEBUG: Successfully saved QR code matrix to " .. filepath)
    return true
end

-- Function to read QR matrix from file
local function read_qr_matrix(file_path)
    print("DEBUG: Reading QR matrix from file: " .. file_path)
    
    local status, result = pcall(function()
        local qr_matrix = {}
        local file = io.open(file_path, "r")
        if not file then
            print("ERROR: Failed to open QR matrix file: " .. file_path)
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
            print("ERROR: QR matrix is empty")
            return nil
        end
        
        return qr_matrix
    end)
    
    if not status then
        print("ERROR: Exception during QR matrix reading: " .. tostring(result))
        return nil
    end
    
    local qr_matrix = result
    if not qr_matrix then
        return nil
    end
    
    print("DEBUG: Successfully read QR matrix, size: " .. #qr_matrix .. "x" .. #qr_matrix[1])
    return qr_matrix
end

-- Function to convert ASCII QR matrix to image
local function convert_qr_to_image(qr_matrix)
    print("DEBUG: Converting QR matrix to drawable function")
    
    local status, result = pcall(function()
        -- Increase the size for better visibility
        local qr_size = 20  -- Increased from 10 to 20 for even better visibility
        local width = #qr_matrix[1] * qr_size
        local height = #qr_matrix * qr_size
        
        print("DEBUG: QR image dimensions: " .. width .. "x" .. height)

        -- Create a white background with black QR code
        local bg = resource.create_colored_texture(0, 0, 0, 0.7)  -- Semi-transparent dark background
        local img = resource.create_colored_texture(1, 1, 1, 1)    -- White background
        local black_pixel = resource.create_colored_texture(0, 0, 0, 1)  -- Black pixel
        local title = "Scan QR Code"
        local font = resource.load_font("default-font.ttf")

        return function(x, y)
            -- Draw semi-transparent background behind the QR code
            local border = 40
            local title_height = 60
            
            -- Draw background with extra space for title
            bg:draw(x - border, y - border - title_height, x + width + border, y + height + border)
            
            -- Draw white background for the QR code
            img:draw(x - border/2, y - border/2, x + width + border/2, y + height + border/2)
            
            -- Draw title text
            font:write(x + width/2 - 100, y - title_height + 10, title, 36, 1, 1, 1, 1)
            
            -- Position the QR code at (x, y)
            for i = 1, #qr_matrix do
                for j = 1, #qr_matrix[i] do
                    if qr_matrix[i][j] == 1 then  -- Draw black square for '1'
                        black_pixel:draw(x + (j-1) * qr_size, y + (i-1) * qr_size, x + j * qr_size, y + i * qr_size)
                    end
                end
            end
            
            print("DEBUG: Drawing QR code at position: " .. x .. "," .. y)
        end
    end)
    
    if not status then
        print("ERROR: Exception during QR image conversion: " .. tostring(result))
        return nil
    end
    
    return result
end

-- Function to handle remote trigger 3 and generate QR code
function M.handle_remote_trigger(data)
    print("DEBUG: Handle remote trigger called with data: " .. data)
    
    if data == "3" then
        print("DEBUG: Trigger 3 activated: Generating QR code")
        
        -- Generate a URL with current timestamp
        local timestamp = format_timestamp()
        local url = "http://activations.courtsidevideo.com?asset_id=12345&timestamp=" .. timestamp .. "&tile_id=7890"
        
        print("DEBUG: Generated URL for QR code: " .. url)
        
        -- Generate QR code and save to file
        print("DEBUG: Starting QR code generation process")
        local qr_generated = generate_qr_code_file(url)
        print("DEBUG: QR code generation result: " .. tostring(qr_generated))
        
        if qr_generated then
            -- Read the QR matrix
            print("DEBUG: Starting QR matrix reading")
            local qr_matrix = read_qr_matrix(base_dir .. "qr_matrix.txt")
            print("DEBUG: QR matrix reading result: " .. tostring(qr_matrix ~= nil))
            
            if qr_matrix then
                -- Convert to drawing function
                print("DEBUG: Creating QR draw function")
                qr_draw_function = convert_qr_to_image(qr_matrix)
                print("DEBUG: QR draw function created: " .. tostring(qr_draw_function ~= nil))
                
                if qr_draw_function then
                    -- Set flag to show QR code
                    show_qr_code = true
                    -- Set expiry time
                    qr_expiry_time = sys.now() + QR_DISPLAY_DURATION
                    print("DEBUG: QR code ready to display for", QR_DISPLAY_DURATION, "seconds")
                    return true
                else
                    print("ERROR: Failed to create QR draw function")
                end
            else
                print("ERROR: Failed to read QR matrix")
            end
        else
            print("ERROR: Failed to generate QR code file")
        end
    end
    return false
end

-- Function to check if QR code should be displayed
function M.show_qr()
    if show_qr_code and qr_draw_function ~= nil then
        print("DEBUG: QR code is ready to be displayed")
        return true
    end
    print("DEBUG: QR code not ready to be displayed. show_qr_code=" .. tostring(show_qr_code) .. ", qr_draw_function=" .. tostring(qr_draw_function ~= nil))
    return false
end

-- Function to draw QR code at specified position
function M.draw_qr(x, y)
    if not show_qr_code then
        print("DEBUG: QR code not set to show")
        return false
    end
    
    if not qr_draw_function then
        print("ERROR: QR draw function is nil")
        return false
    end
    
    if sys.now() > qr_expiry_time then
        print("DEBUG: QR code display time expired")
        show_qr_code = false
        return false
    else
        -- Add more detailed logging
        print("DEBUG: Drawing QR code at position: " .. x .. "," .. y .. " - Expires in: " .. math.floor(qr_expiry_time - sys.now()) .. " seconds")
        
        local status, err = pcall(function()
            qr_draw_function(x, y)
        end)
        
        if not status then
            print("ERROR: Exception during QR drawing: " .. tostring(err))
            show_qr_code = false
            return false
        end
        
        return true
    end
end

return M 