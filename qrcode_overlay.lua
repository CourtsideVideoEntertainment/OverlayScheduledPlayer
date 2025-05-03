-- qrcode_overlay.lua
-- This module handles QR code generation and display for info-beamer

local M = {}

-- Variables for QR code functionality
local show_qr_code = false
local qr_draw_function = nil
local qr_expiry_time = 0
local QR_DISPLAY_DURATION = 60  -- Show QR code for 60 seconds
local qrencode = {}  -- Initialize empty table for qrencode module

-- Function to format current time as DDMMYYHHMM
local function format_timestamp()
    local time = os.date("*t")
    return string.format("%02d%02d%02d%02d%02d", 
        time.day, time.month, time.year % 100, time.hour, time.min)
end

-- Function to generate QR code and save it to a file
local function generate_qr_code_file(data)
    -- Load the qrencode module if not already loaded
    if not qrencode.qrcode then
        qrencode = dofile("qrencode.lua")
    end
    
    local ok, matrix = qrencode.qrcode(data)
    if not ok then
        print("QR code generation failed:", matrix)
        return false
    end
    
    local file = io.open("qr_matrix.txt", "w")
    if not file then
        print("Failed to open file for writing")
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
    
    print("Saved QR code matrix to qr_matrix.txt")
    return true
end

-- Function to read QR matrix from file
local function read_qr_matrix(file_path)
    local qr_matrix = {}
    local file = io.open(file_path, "r")
    if not file then
        print("Failed to open QR matrix file")
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
    return qr_matrix
end

-- Function to convert ASCII QR matrix to image
local function convert_qr_to_image(qr_matrix)
    local qr_size = 5  -- Size of each QR code module (smaller for top left corner)
    local width = #qr_matrix[1] * qr_size
    local height = #qr_matrix * qr_size

    -- Create a white background with black QR code
    local img = resource.create_colored_texture(1, 1, 1, 1)  -- White background
    local black_pixel = resource.create_colored_texture(0, 0, 0, 1)  -- Black pixel

    return function(x, y)
        -- Draw white background for the QR code
        img:draw(x, y, x + width, y + height)
        
        -- Position the QR code at (x, y)
        for i = 1, #qr_matrix do
            for j = 1, #qr_matrix[i] do
                if qr_matrix[i][j] == 1 then  -- Draw black square for '1'
                    black_pixel:draw(x + (j-1) * qr_size, y + (i-1) * qr_size, x + j * qr_size, y + i * qr_size)
                end
            end
        end
    end
end

-- Function to handle remote trigger 3 and generate QR code
function M.handle_remote_trigger(data)
    if data == "3" then
        print("Trigger 3 activated: Generating QR code")
        
        -- Generate a URL with current timestamp
        local timestamp = format_timestamp()
        local url = "http://activations.courtsidevideo.com?asset_id=12345&timestamp=" .. timestamp .. "&tile_id=7890"
        
        -- Generate QR code and save to file
        if generate_qr_code_file(url) then
            -- Read the QR matrix
            local qr_matrix = read_qr_matrix("qr_matrix.txt")
            if qr_matrix then
                -- Convert to drawing function
                qr_draw_function = convert_qr_to_image(qr_matrix)
                -- Set flag to show QR code
                show_qr_code = true
                -- Set expiry time
                qr_expiry_time = sys.now() + QR_DISPLAY_DURATION
                print("QR code ready to display for", QR_DISPLAY_DURATION, "seconds")
                return true
            end
        end
    end
    return false
end

-- Function to check if QR code should be displayed
function M.show_qr()
    return show_qr_code and qr_draw_function ~= nil
end

-- Function to draw QR code at specified position
function M.draw_qr(x, y)
    if show_qr_code and qr_draw_function then
        if sys.now() > qr_expiry_time then
            show_qr_code = false
            print("QR code display time expired")
            return false
        else
            qr_draw_function(x, y)
            return true
        end
    end
    return false
end

return M 