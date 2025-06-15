-- Coke Zero Overlay Module
-- This module displays a Coke Zero PNG image as an overlay
-- Can be positioned anywhere on screen with configurable transparency

local helper = require "helper"

local M = {}

-- Default configuration
local config = {
    position = "top-right",  -- top-left, top-right, bottom-left, bottom-right, center, custom
    margin = 20,             -- margin from edges in pixels
    custom_x = 0,            -- custom X position (0-100% of screen width)
    custom_y = 0,            -- custom Y position (0-100% of screen height)
    scale = 1.0,             -- scale factor (1.0 = original size)
    alpha = 1.0,             -- transparency (0.0 = invisible, 1.0 = opaque)
    fade_time = 0.5,         -- fade in/out time in seconds
    asset_name = "Coke_Zero_Revised_1_lowres.png"  -- default asset name
}

local image_cache = nil

function M.updated_config_json(new_config)
    -- Update configuration
    for key, value in pairs(new_config) do
        config[key] = value
    end
    
    -- Clear image cache to reload with new settings
    if image_cache then
        image_cache:dispose()
        image_cache = nil
    end
    
    print("[COKE_OVERLAY] Config updated:", config.position, "margin:", config.margin, "alpha:", config.alpha)
end

function M.task(starts, ends, tile_config, x1, y1, x2, y2)
    -- Merge tile config with module config
    local final_config = {}
    for k, v in pairs(config) do
        final_config[k] = v
    end
    for k, v in pairs(tile_config) do
        final_config[k] = v
    end
    
    -- Load the Coke Zero image
    if not image_cache then
        image_cache = resource.load_image{
            file = final_config.asset_name,
            mipmap = true,
        }
    end
    
    -- Get image dimensions
    local img_width, img_height = image_cache:size()
    
    -- Apply scaling
    local scaled_width = img_width * final_config.scale
    local scaled_height = img_height * final_config.scale
    
    -- Calculate position based on configuration
    local draw_x, draw_y
    
    if final_config.position == "top-left" then
        draw_x = x1 + final_config.margin
        draw_y = y1 + final_config.margin
    elseif final_config.position == "top-right" then
        draw_x = x2 - scaled_width - final_config.margin
        draw_y = y1 + final_config.margin
    elseif final_config.position == "bottom-left" then
        draw_x = x1 + final_config.margin
        draw_y = y2 - scaled_height - final_config.margin
    elseif final_config.position == "bottom-right" then
        draw_x = x2 - scaled_width - final_config.margin
        draw_y = y2 - scaled_height - final_config.margin
    elseif final_config.position == "center" then
        draw_x = x1 + (x2 - x1) / 2 - scaled_width / 2
        draw_y = y1 + (y2 - y1) / 2 - scaled_height / 2
    elseif final_config.position == "custom" then
        -- Custom positioning using percentages
        local area_width = x2 - x1
        local area_height = y2 - y1
        draw_x = x1 + (area_width * final_config.custom_x / 100)
        draw_y = y1 + (area_height * final_config.custom_y / 100)
    else
        -- Default to top-right
        draw_x = x2 - scaled_width - final_config.margin
        draw_y = y1 + final_config.margin
    end
    
    -- Display the overlay
    for now in helper.frame_between(starts, ends) do
        local alpha = final_config.alpha * helper.ramp(starts, ends, now, final_config.fade_time)
        image_cache:draw(draw_x, draw_y, draw_x + scaled_width, draw_y + scaled_height, alpha)
    end
end

-- Optional: Auto-duration for standalone use
function M.auto_duration()
    return 10  -- Default 10 seconds if used as standalone
end

-- Optional: Can show check
function M.can_show(tile_config)
    return true  -- Always show
end

return M 