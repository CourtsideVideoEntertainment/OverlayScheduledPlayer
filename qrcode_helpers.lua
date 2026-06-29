-- gl.setup(NATIVE_WIDTH, NATIVE_HEIGHT)

-- node.alias "*"
-- util.no_globals()
-- math.randomseed(os.time())

local function create_or_update_qr_instance(asset_id, position_config)
    local instance_id = "qr_" .. tostring(asset_id)
    
    local default_config = {
        position = "bottom-right",
        margin = 20,
        custom_x = 0,
        custom_y = 0
    }
    
    local final_config = {}
    for k, v in pairs(default_config) do
        final_config[k] = v
    end
    if position_config then
        for k, v in pairs(position_config) do
            final_config[k] = v
        end
    end
    
    -- Create or update the instance
    local existing = qr_code_instances[instance_id]
    if existing then
        existing.trigger_data = tostring(asset_id)
        existing.position_config = final_config
        existing.draw_details = nil
        existing.is_visible = false
    else
        qr_code_instances[instance_id] = {
            id = instance_id,
            trigger_data = tostring(asset_id),
            position_config = final_config,
            draw_details = nil,
            is_visible = false
        }
    end
    
    -- Auto-save after creating/updating instance
    save_qr_instances()
    
    return instance_id
end

local function remove_qr_instance(asset_id)
    local instance_id = "qr_" .. tostring(asset_id)
    if qr_code_instances[instance_id] then
        qr_code_instances[instance_id] = nil
        save_qr_instances()
        return true
    end
    return false
end

local function list_qr_instances()
    local instances = {}
    for id, instance in pairs(qr_code_instances) do
        instances[id] = {
            asset_id = instance.trigger_data,
            position_config = instance.position_config,
            is_visible = instance.is_visible,
            has_draw_details = instance.draw_details ~= nil
        }
    end
    return instances
end

local function get_qr_instance(asset_id)
    local instance_id = "qr_" .. tostring(asset_id)
    return qr_code_instances[instance_id]
end

local function save_qr_instances()
    local data_to_save = {}
    for id, instance in pairs(qr_code_instances) do
        data_to_save[id] = {
            id = instance.id,
            trigger_data = instance.trigger_data,
            position_config = instance.position_config,
            -- Don't save draw_details or is_visible as they're runtime state
        }
    end
    
    local success = pcall(function()
        local file = io.open("qr_instances.json", "w")
        if file then
            file:write(json.encode(data_to_save))
            file:close()
        end
    end)
    
end

local function load_qr_instances()
    local success, data = pcall(function()
        local file = io.open("qr_instances.json", "r")
        if file then
            local content = file:read("*all")
            file:close()
            return json.decode(content)
        end
        return nil
    end)
    
    if success and data then
        for id, instance_data in pairs(data) do
            qr_code_instances[id] = {
                id = instance_data.id,
                trigger_data = instance_data.trigger_data,
                position_config = instance_data.position_config,
                draw_details = nil,
                is_visible = false
            }
        end
        return true
    end
    return false
end



local function update_qr_position(instance_id, settings)
    print("Attempting to update QR positioning for instance: " .. tostring(instance_id))

    local instance = qr_code_instances[instance_id]
    if not instance then
        print("ERROR: Cannot update position for non-existent QR instance ID: " .. tostring(instance_id))
        return false
    end

    if type(settings) ~= "table" then
        print("ERROR: Settings must be a table")
        return false
    end

    -- Ensure the instance has a position_config table
    if not instance.position_config then
        instance.position_config = { position = "bottom-right", margin = 20, custom_x = 0, custom_y = 0 } -- Initialize if missing
    end

    local config_updated = false
    -- Update individual settings if provided
    if settings.position then
        -- Validate position value
        local valid_positions = {
            ["top-left"] = true,
            ["top-right"] = true,
            ["bottom-left"] = true,
            ["bottom-right"] = true,
            ["custom"] = true
        }

        if valid_positions[settings.position] then
            instance.position_config.position = settings.position
            print("Instance " .. instance_id .. ": Updated position to " .. settings.position)
            config_updated = true
        else
            print("ERROR: Invalid position value: " .. settings.position)
        end
    end

    if settings.margin then
        instance.position_config.margin = settings.margin
        print("Instance " .. instance_id .. ": Updated margin to " .. settings.margin)
        config_updated = true
    end

    -- Handle custom_x and custom_y as percentages
    if settings.custom_x ~= nil then
        instance.position_config.custom_x = settings.custom_x
        print("Instance " .. instance_id .. ": Updated custom_x to " .. settings.custom_x .. "%")
        config_updated = true
    end

    if settings.custom_y ~= nil then
        instance.position_config.custom_y = settings.custom_y
        print("Instance " .. instance_id .. ": Updated custom_y to " .. settings.custom_y .. "%")
        config_updated = true
    end

    return config_updated
end

-- Helper function to validate and explain QR positioning relative to gl.setup dimensions
local function validate_qr_positioning(instance_id)
    local instance = qr_code_instances[instance_id]
    if not instance or not instance.position_config then
        print("ERROR: Invalid QR instance for positioning validation: " .. tostring(instance_id))
        return false
    end
    
    local pos_config = instance.position_config
    
    print("\n=== QR POSITIONING VALIDATION for " .. instance_id .. " ===")
    print("GL Setup Dimensions: " .. NATIVE_WIDTH .. " x " .. NATIVE_HEIGHT .. " pixels")
    print("Position Mode: " .. (pos_config.position or "unknown"))
    
    if pos_config.position == "custom" then
        local x_percent = pos_config.custom_x or 0
        local y_percent = pos_config.custom_y or 0
        local pixel_x = NATIVE_WIDTH * x_percent / 100
        local pixel_y = NATIVE_HEIGHT * y_percent / 100
        
        print("Custom Position:")
        print("  - X: " .. x_percent .. "% = " .. math.floor(pixel_x) .. " pixels from left")
        print("  - Y: " .. y_percent .. "% = " .. math.floor(pixel_y) .. " pixels from top")
        print("  - Coordinate System: (0,0) = top-left, (100,100) = bottom-right")
        
        -- Validate ranges
        if x_percent < 0 or x_percent > 100 then
            print("WARNING: custom_x (" .. x_percent .. "%) is outside 0-100% range")
        end
        if y_percent < 0 or y_percent > 100 then
            print("WARNING: custom_y (" .. y_percent .. "%) is outside 0-100% range")
        end
    else
        print("Preset Position: " .. (pos_config.position or "unknown"))
        print("Margin: " .. (pos_config.margin or 20) .. " pixels")
    end
    
    print("=== END VALIDATION ===\n")
    return true
end


util.data_mapper{
    ["qr/position"] = function(data)
        local payload = json.decode(data)
        if type(payload) == "table" and payload.id and payload.settings then
            update_qr_position(payload.id, payload.settings)
        end
    end,
    ["qr/appearance"] = function(data)
        local settings = json.decode(data)
        local needs_regen = qrcode_overlay.update_appearance(settings)
        if needs_regen then
            for id, instance in pairs(qr_code_instances) do
                if instance.is_visible and instance.trigger_data then
                    local new_draw_details = qrcode_overlay.handle_remote_trigger(instance.trigger_data, current_setup_id)
                    if new_draw_details then
                        instance.draw_details = new_draw_details
                    else
                        instance.is_visible = false
                        instance.draw_details = nil
                    end
                end
            end
        end
    end,
    ["qr/validate"] = function(data)
        local payload = json.decode(data)
        if type(payload) == "table" and payload.id then
            validate_qr_positioning(payload.id)
        elseif type(payload) == "string" then
            -- Allow direct string ID
            validate_qr_positioning(payload)
        else
            -- Validate all instances if no specific ID provided
            print("Validating all QR instances...")
            for id, _ in pairs(qr_code_instances) do
                validate_qr_positioning(id)
            end
        end
    end,
    -- === COKE ZERO OVERLAY HANDLERS ===
    ["coke/load"] = function(data)
        local asset_name = data and data ~= "" and data or "Coke_Zero_Revised_1_lowres.png"
        load_coke_overlay(asset_name)
        log("coke_overlay", "Load command received for asset: %s", asset_name)
    end,

    ["coke/toggle"] = function(data)
        coke_overlay.enabled = not coke_overlay.enabled
        log("coke_overlay", "Overlay toggled: %s", coke_overlay.enabled and "enabled" or "disabled")
    end,

    ["coke/position"] = function(data)
        local payload = json.decode(data)
        if type(payload) == "table" then
            if payload.position then coke_overlay.position = payload.position end
            if payload.margin then coke_overlay.margin = payload.margin end
            if payload.custom_x then coke_overlay.custom_x = payload.custom_x end
            if payload.custom_y then coke_overlay.custom_y = payload.custom_y end
            log("coke_overlay", "Position updated: %s (margin: %d)", coke_overlay.position, coke_overlay.margin)
        elseif type(payload) == "string" then
            coke_overlay.position = payload
            log("coke_overlay", "Position set to: %s", payload)
        end
    end,

    ["coke/appearance"] = function(data)
        local payload = json.decode(data)
        if type(payload) == "table" then
            if payload.scale then coke_overlay.scale = payload.scale end
            if payload.alpha then coke_overlay.alpha = payload.alpha end
            log("coke_overlay", "Appearance updated: scale=%.2f, alpha=%.2f", coke_overlay.scale, coke_overlay.alpha)
        end
    end,
	    -- API: Create or update QR code instance
    ["qr/instance"] = function(data)
        local payload = json.decode(data or "{}")
        
        if not payload.asset_id then
            log("qr", "ERROR: asset_id required")
            return
        end
        
        local position_config = {}
        if payload.position then position_config.position = payload.position end
        if payload.margin then position_config.margin = payload.margin end
        if payload.custom_x then position_config.custom_x = payload.custom_x end
        if payload.custom_y then position_config.custom_y = payload.custom_y end
        
        local instance_id = create_or_update_qr_instance(payload.asset_id, position_config)
        log("qr", "Created/updated QR instance: %s", instance_id)
        
        if payload.auto_show then
            local instance = qr_code_instances[instance_id]
            if instance then
                local new_draw_details = qrcode_overlay.handle_remote_trigger(instance.trigger_data, current_setup_id)
                if new_draw_details then
                    instance.draw_details = new_draw_details
                    instance.is_visible = true
                    log("qr", "Auto-showing QR instance: %s", instance_id)
                else
                    log("qr", "ERROR: Failed to generate QR for instance: %s", instance_id)
                end
            end
        end
    end,
    
    -- API: Remove QR code instance
    ["qr/instance/remove"] = function(data)
        local payload = json.decode(data)
        if payload.asset_id and remove_qr_instance(payload.asset_id) then
            log("qr", "Removed QR instance: %s", payload.asset_id)
        end
    end,
    
    -- API: List all QR code instances
    ["qr/instance/list"] = function(data)
        local instances = list_qr_instances()
        log("qr", "QR instances: %d", table.getn(instances))
        for id, info in pairs(instances) do
            log("qr", "  %s: %s (%s)", id, info.asset_id, info.position_config.position or "default")
        end
    end,
    
    -- API: Get specific QR instance info
    ["qr/instance/get"] = function(data)
        local payload = json.decode(data)
        
        if not payload.asset_id then
            print("[QR_PACKAGE] ERROR: asset_id is required")
            return
        end
        
        local instance = get_qr_instance(payload.asset_id)
        if instance then
            print("[QR_PACKAGE] QR instance for asset_id " .. payload.asset_id .. ":")
            print("[QR_PACKAGE]   ID: " .. instance.id)
            print("[QR_PACKAGE]   Visible: " .. tostring(instance.is_visible))
            print("[QR_PACKAGE]   Position: " .. (instance.position_config.position or "unknown"))
            print("[QR_PACKAGE]   Custom X/Y: " .. (instance.position_config.custom_x or 0) .. "%, " .. (instance.position_config.custom_y or 0) .. "%")
            print("[QR_PACKAGE]   Margin: " .. (instance.position_config.margin or 20))
        else
            print("[QR_PACKAGE] No QR instance found for asset_id: " .. payload.asset_id)
        end
    end,
    -- SETUP-WIDE: QR instance management that syncs across all devices
    ["setup/qr/instance"] = function(data)
        local payload = json.decode(data)
        
        if not payload.asset_id then
            log("QR_SETUP", "ERROR: asset_id is required")
            return
        end
        
        local position_config = {}
        
        -- Extract position configuration from payload
        if payload.position then position_config.position = payload.position end
        if payload.margin then position_config.margin = payload.margin end
        if payload.custom_x then position_config.custom_x = payload.custom_x end
        if payload.custom_y then position_config.custom_y = payload.custom_y end
        
        -- Create or update the instance
        local instance_id = create_or_update_qr_instance(payload.asset_id, position_config)
        
        log("QR_SETUP", "Setup-wide QR instance created/updated for asset_id: %s (instance: %s)", 
            payload.asset_id, instance_id)
        
        -- If auto_show is true, immediately make it visible and generate QR
        if payload.auto_show then
            local instance = qr_code_instances[instance_id]
            if instance then
                local new_draw_details = qrcode_overlay.handle_remote_trigger(instance.trigger_data, current_setup_id)
                if new_draw_details then
                    instance.draw_details = new_draw_details
                    instance.is_visible = true
                    log("QR_SETUP", "Auto-showing setup-wide QR instance: %s", instance_id)
                else
                    log("QR_SETUP", "ERROR: Failed to generate QR for auto_show instance: %s", instance_id)
                end
            end
        end
    end,
    
    -- SETUP-WIDE: Remove QR instance across all devices
    ["setup/qr/instance/remove"] = function(data)
        local payload = json.decode(data)
        
        if not payload.asset_id then
            log("QR_SETUP", "ERROR: asset_id is required for removal")
            return
        end
        
        local success = remove_qr_instance(payload.asset_id)
        if success then
            log("QR_SETUP", "Successfully removed setup-wide QR instance for asset_id: %s", payload.asset_id)
        else
            log("QR_SETUP", "No QR instance found for asset_id: %s", payload.asset_id)
        end
    end,
    
    -- SETUP-WIDE: List all QR instances (same as device-level)
    ["setup/qr/instance/list"] = function(data)
        local instances = list_qr_instances()
        log("QR_SETUP", "Setup-wide QR instances:")
        for id, info in pairs(instances) do
            log("QR_SETUP", "  %s: asset_id=%s, visible=%s, position=%s (%.1f%%, %.1f%%)", 
                id, info.asset_id, tostring(info.is_visible), 
                info.position_config.position or "unknown",
                info.position_config.custom_x or 0,
                info.position_config.custom_y or 0)
        end
        if not next(instances) then
            log("QR_SETUP", "  No QR instances found")
        end
    end,
    -- API: Create or update QR code instance (with root/ prefix)
    ["root/qr/instance"] = function(data)
        print("[QR_PACKAGE] root/qr/instance handler called")
        print("[QR_PACKAGE] Raw data type: " .. type(data))
        print("[QR_PACKAGE] Raw data content: '" .. tostring(data) .. "'")
        print("[QR_PACKAGE] Raw data length: " .. string.len(tostring(data)))
        
        -- If data is empty, it might be that info-beamer passes the data differently
        -- Let's try to handle both cases: direct JSON string and empty data
        local payload
        local success, err = pcall(function()
            if data == "" or data == nil then
                -- If data is empty, maybe info-beamer doesn't pass the inner JSON
                -- In this case, we'll assume the API call structure is different
                print("[QR_PACKAGE] Data is empty - this might be normal for info-beamer API")
                payload = {
                    asset_id = "3",  -- Default for testing
                    custom_x = 20,
                    custom_y = 30,
                    position = "custom",
                    auto_show = true
                }
            else
                payload = json.decode(data)
            end
        end)
        
        if not success then
            print("[QR_PACKAGE] JSON decode failed: " .. tostring(err))
            return
        end
        
        print("[QR_PACKAGE] Decoded payload type: " .. type(payload))
        print("[QR_PACKAGE] Payload asset_id: " .. tostring(payload.asset_id))
        
        if not payload.asset_id then
            print("[QR_PACKAGE] ERROR: asset_id is required")
            return
        end
        
        local position_config = {}
        
        -- Extract position configuration from payload
        if payload.position then position_config.position = payload.position end
        if payload.margin then position_config.margin = payload.margin end
        if payload.custom_x then position_config.custom_x = payload.custom_x end
        if payload.custom_y then position_config.custom_y = payload.custom_y end
        
        -- Create or update the instance
        local instance_id = create_or_update_qr_instance(payload.asset_id, position_config)
        
        print("[QR_PACKAGE] Successfully created/updated QR instance for asset_id: " .. payload.asset_id .. " (instance: " .. instance_id .. ")")
        
        -- If auto_show is true, immediately make it visible and generate QR
        if payload.auto_show then
            local instance = qr_code_instances[instance_id]
            if instance then
                print("[QR_PACKAGE] Attempting to auto-show QR instance: " .. instance_id .. " with trigger_data: " .. instance.trigger_data)
                print("[QR_PACKAGE] Current setup_id: " .. tostring(current_setup_id))
                local new_draw_details = qrcode_overlay.handle_remote_trigger(instance.trigger_data, current_setup_id)
                if new_draw_details then
                    instance.draw_details = new_draw_details
                    instance.is_visible = true
                    print("[QR_PACKAGE] Auto-showing QR instance: " .. instance_id .. " - SUCCESS")
                else
                    print("[QR_PACKAGE] ERROR: Failed to generate QR for auto_show instance: " .. instance_id)
                    print("[QR_PACKAGE] qrcode_overlay.handle_remote_trigger returned nil")
                end
            else
                print("[QR_PACKAGE] ERROR: Instance not found for auto_show: " .. instance_id)
            end
        end
    end,
    
    -- API: Remove QR code instance (with root/ prefix)
    ["root/qr/instance/remove"] = function(data)
        print("[QR_PACKAGE] root/qr/instance/remove handler called")
        local payload = json.decode(data)
        
        if not payload.asset_id then
            print("[QR_PACKAGE] ERROR: asset_id is required for removal")
            return
        end
        
        local success = remove_qr_instance(payload.asset_id)
        if success then
            print("[QR_PACKAGE] Successfully removed QR instance for asset_id: " .. payload.asset_id)
        else
            print("[QR_PACKAGE] No QR instance found for asset_id: " .. payload.asset_id)
        end
    end,
    
    -- API: List all QR code instances (with root/ prefix)
    ["root/qr/instance/list"] = function(data)
        print("[QR_PACKAGE] root/qr/instance/list handler called")
        local instances = list_qr_instances()
        print("[QR_PACKAGE] Current QR instances:")
        for id, info in pairs(instances) do
            print("[QR_PACKAGE]   " .. id .. ": asset_id=" .. info.asset_id .. ", visible=" .. tostring(info.is_visible) .. 
                  ", position=" .. (info.position_config.position or "unknown") .. 
                  " (" .. (info.position_config.custom_x or 0) .. "%, " .. (info.position_config.custom_y or 0) .. "%)")
        end
        if not next(instances) then
            print("[QR_PACKAGE]   No QR instances found")
        end
    end,
}

	

local function initialize_qr_codes()
    print("Initializing predefined QR codes...")
    for id, instance in pairs(qr_code_instances) do
        if instance.is_visible then -- Check if it's set to be visible initially
            print("Pre-generating QR for initially visible instance: " .. id)
            local new_draw_details = qrcode_overlay.handle_remote_trigger(instance.trigger_data, current_setup_id)
            if new_draw_details then
                instance.draw_details = new_draw_details
                print("Successfully pre-generated QR for instance: " .. id)
            else
                print("ERROR: Failed to pre-generate QR for instance: " .. id)
                instance.is_visible = false -- Don't show if generation failed
            end
        end
    end
end	