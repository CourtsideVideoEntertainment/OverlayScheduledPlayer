

local function ExternalEvents()
    local forward_keyboard = true

    node.event("config_updated", function(config)
        forward_keyboard = config.forward_keyboard
    end)

    util.data_mapper{
        ["event/keyboard"] = function(raw_event)
            if forward_keyboard then
                local event = json.decode(raw_event)
                dispatch_to_all_tiles("on_keyboard", event)
                return scheduler.handle_keyboard(event)
            end
        end,
        ["event/pad"] = function(raw_event)
            local event = json.decode(raw_event)
            dispatch_to_all_tiles("on_pad", event)
            return scheduler.handle_gamepad(event)
        end,
        ["event/gpio"] = function(raw_event)
            local event = json.decode(raw_event)
            dispatch_to_all_tiles("on_gpio", event)
            return scheduler.handle_gpio(event)
        end,
        ["remote/trigger"] = function(data)
            return scheduler.handle_remote_trigger(data)
        end,
        ["sys/cec/key"] = scheduler.handle_cec,
        ["plugin/(.*)/(.*)"] = function(tile_name, path, data)
            local impl = tile_loader.modules[tile_name]
            if impl and impl.data_trigger then
                impl.data_trigger(path, data)
            end
        end,
    }
end

local ExternalEvents = ExternalEvents()