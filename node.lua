gl.setup(NATIVE_WIDTH, NATIVE_HEIGHT)

node.alias "*" -- catch all communication

util.no_globals()

math.randomseed(os.time())

local json = require "json"
local loader = require "loader"
local helper = require "helper"
local placement = require "placement"
local easing = require "easing"
local qrcode_overlay = require "qrcode_overlay"

-- QR code positioning configuration - REMOVED Global config
-- local QR_POSITION_CONFIG = { ... }

-- NEW: Predefined QR code instances
local qr_code_instances = {
    activation_qr = {
        id = "activation_qr",
        trigger_data = "3", -- Data used to generate this QR code's content
        position_config = {
            position = "bottom-right",
            margin = 20,
            custom_x = 0,
            custom_y = 0
        },
        draw_details = nil, -- Will be populated by handle_remote_trigger
        is_visible = false   -- Initially not visible
    },
    permanent_info_qr = {
        id = "permanent_info_qr",
        trigger_data = "3", -- Data used to generate this QR code's content
        position_config = {
            position = "top-left",
            margin = 30, -- Different margin for this instance
            custom_x = 0,
            custom_y = 0
        },
        draw_details = nil,
        is_visible = false
    }
    -- Add more predefined instances here if needed
    -- example_qr = {
    --     id = "example_qr",
    --     trigger_data = "some_other_trigger_value_if_qrcode_overlay_handles_it",
    --     position_config = { position = "custom", custom_x = 100, custom_y = 100, margin = 10},
    --     draw_details = nil,
    --     is_visible = false
    -- }
}

local min, max, abs, floor, ceil = math.min, math.max, math.abs, math.floor, math.ceil

local font_regl = resource.load_font "default-font.ttf"
local font_bold = resource.load_font "default-font-bold.ttf"
local font_7seg = resource.load_font "7segment.ttf"

-- Create persistent marker texture for debug visualization
local debug_marker = resource.create_colored_texture(1, 0, 0, 1)  -- Red square

local colored = resource.create_shader[[
    uniform sampler2D Texture;
    varying vec2 TexCoord;
    uniform vec4 color;
    void main() {
        gl_FragColor = texture2D(Texture, TexCoord) * color;
    }
]]

local white_pixel = resource.create_colored_texture(1,1,1,1)

local function log(system, format, ...)
    return print(string.format("[%s] " .. format, system, ...))
end

local function permute(tab)
    for i = 1, #tab do
        local j = math.random(i, #tab)
        tab[i], tab[j] = tab[j], tab[i]
    end
end

local function json_nullify(val)
    if val == json.null then
        return
    else
        return val
    end
end

local function startswith(str, prefix)
    return str:sub(1, #prefix) == prefix
end

local function Music()
    local asset_name = nil
    local music = nil

    node.event("config_updated", function(config)
        log("music", "updating music config settings")
        if config.music.asset_id == "mute.mp4" then
            if music then
                music:dispose()
            end
            asset_name = nil
            music = nil
        elseif config.music.asset_name ~= asset_name then
            if music then
                music:dispose()
            end
            asset_name = config.music.asset_name
            music = resource.load_video{
                file = config.music.asset_name,
                looped = true,
                audio = true,
                raw = true,
            }
        end
    end)
end

local music = Music()

local function TCPClients()
    local clients = {}
    local handlers = {}

    node.event("connect", function(client, path)
        log("tcpclient", "new tcp client for %s", path)
        clients[client] = {
            path = path;
            send = function(...)
                node.client_write(client, ...)
            end
        }
    end)

    node.event("input", function(line, client)
        local cinfo = clients[client]
        if handlers[cinfo.path] then
            handlers[cinfo.path](line)
        end
    end)

    node.event("disconnect", function(client)
        clients[client] = nil
    end)

    local function send(path, ...)
        for client, cinfo in pairs(clients) do
            if cinfo.path == path then
                cinfo.send(...)
            end
        end
    end

    local function add_handler(path, handler)
        handlers[path] = handler
    end

    return {
        send = send;
        add_handler = add_handler;
    }
end

local tcp_clients = TCPClients()

local function Screen()
    local placer
    local rotation
    local frame_time = 1/60

    pcall(function()
        local fps, swap_interval = sys.get_ext("screen").get_display_info()
        frame_time = 1 / fps * swap_interval
        log("screen", "detected frame delay is %f", frame_time)
    end)

    node.event("config_updated", function(config)
        rotation = config.rotation
        local is_portrait = rotation == 90 or rotation == 270
        local width, height = config.resolution[1], config.resolution[2]
        log("screen", "configured content resolution is %dx%d", width, height)

        local surface = {
            width = width,
            height = height,
        }

        local target = {
            x = 0,
            y = 0,
            width = NATIVE_WIDTH,
            height = NATIVE_HEIGHT,
            rotation = rotation,
        }

        if is_portrait then
            surface.width, surface.height = surface.height, surface.width
        end

        placer = placement.Screen(target, surface)
    end)

    local function setup()
        return placer.setup()
    end

    local function place_video(...)
        return placer.place(...)
    end

    local function set_scissor(...)
        return placer.scissor(...)
    end

    local function get_rotation()
        return rotation
    end

    return {
        setup = setup;
        place_video = place_video;
        set_scissor = set_scissor;
        frame_time = frame_time;
        get_rotation = get_rotation;
    }
end

local screen = Screen()

local function FontCache()
    local fonts = {}

    local function get(filename)
        local font = fonts[filename]
        if not font then
            font = {
                obj = resource.load_font(filename),
            }
            fonts[filename] = font
        end
        font.lru = sys.now()
        return font.obj
    end

    local function tick()
        for filename, font in pairs(fonts) do
            if sys.now() - font.lru > 300 then
                log("fontcache", "purging font %s", filename)
                fonts[filename] = nil
            end
        end
    end

    return {
        get = get;
        tick = tick;
    }
end

local FontCache = FontCache()

local error_img = resource.create_colored_texture(1,0,0,1)
local function ImageCache()
    local images = {}

    local get, register

    function get(asset_name, keep)
        if not images[asset_name] then
            register(asset_name, keep)
        end
        local image = images[asset_name]
        if not image then
            return error_img
        end
        if not image.obj then
            image.obj = resource.load_image{
                file = image.file,
                fastload = true,
            }
        end
        image.lru = max(image.lru, sys.now() + keep)
        return image.obj
    end

    function register(asset_name, keep)
        log("imagecache", "register %s %d", asset_name, keep)
        if not images[asset_name] then
            images[asset_name] = {
                file = resource.open_file(asset_name),
                lru = sys.now() + keep
            }
        end
        return function(keep)
            return get(asset_name, keep or 0)
        end
    end

    local function tick()
        for asset_name, image in pairs(images) do
            local max_age = 0.5
            if not image.obj then
                max_age = 10
            end
            if sys.now() - image.lru > max_age then
              log("imagecache", "purging image %s", asset_name)
              image.file:dispose()
              if image.obj then
                  image.obj:dispose()
              end
              images[asset_name] = nil
            end
        end
    end

    return {
        register = register;
        get = get;
        tick = tick;
    }
end

local ImageCache = ImageCache()

local function Clock()
    local has_time = false
    local time = {diff=0}
    local updated = sys.now()

    local function since_midnight()
        local delta = sys.now() - updated
        local seconds = (time.since_midnight + delta) % 86400
        return seconds
    end

    return {
        update = function(new_time)
            time = new_time
            has_time = true
            updated = sys.now()
        end;
        has_time = function()
            return has_time
        end;
        human = function()
            local t = since_midnight()
            return string.format("%02d:%02d", math.floor(t / 3600), math.floor(t % 3600 / 60))
        end;
        unix = function()
            return os.time() + time.diff
        end;
        week_hour = function()
            return time.week_hour
        end;
        day_of_week = function()
            return time.dow
        end;
        since_midnight = since_midnight;
        today = function()
            return {
                day = time.day;
                month = time.month;
                year = time.year;
            }
        end;
    }
end

local function Clocks()
    local tz_clocks = {}

    local function create_and_get(tz)
        if not tz_clocks[tz] then
            tz_clocks[tz] = Clock()
        end
        return tz_clocks[tz]
    end

    util.data_mapper{
        ["clock/(.*)"] = function(tz, data)
            local time = json.decode(data)
            local clock = create_and_get(tz)
            clock.update(time)
        end;
    }

    return {
        get = create_and_get;
    }
end

local Clocks = Clocks()

local function Countdowns()
    local countdowns = {}

    util.data_mapper{
        ["countdown"] = function(update)
            local update = json.decode(update)
            countdowns[update.target] = update.unix
        end;
    }

    local function delta(target)
        local unix = countdowns[target]
        if not unix then
            return 0
        end
        return unix - os.time()
    end

    return {
        delta = delta;
    }
end

local Countdowns = Countdowns()


-- clock object pointing to the configured schedule timezone
local schedule_clock = setmetatable({
    tz = "UTC",
}, {
    __index = function(config, key)
        return Clocks.get(config.tz)[key]
    end,
})
node.event("config_updated", function(config)
    if config.timezone == "device" then
        schedule_clock.tz = config.__metadata.timezone
    else
        schedule_clock.tz = config.timezone
    end
end)

local function clock_for_tz_or_default(tz)
    if tz then
        return Clocks.get(tz)
    else
        return schedule_clock
    end
end

local SharedData = function()
    -- {
    --    scope: { key: data }
    -- }
    local data = {}

    -- {
    --    key: { scope: listener }
    -- }
    local listeners = {}

    local function call_listener(scope, listener, key, value)
        local ok, err = xpcall(listener, debug.traceback, scope, value)
        if not ok then
            log("shareddata", "while calling listener for key %s: %s", key, err)
        end
    end

    local function call_listeners(scope, key, value)
        local key_listeners = listeners[key]
        if not key_listeners then
            return
        end

        for _, listener in pairs(key_listeners) do
            call_listener(scope, listener, key, value)
        end
    end

    local function update(scope, key, value)
        if not data[scope] then
            data[scope] = {}
        end
        data[scope][key] = value
        if value == nil and not next(data[scope]) then
            data[scope] = nil
        end
        return call_listeners(scope, key, value)
    end

    local function delete(scope, key)
        return update(scope, key, nil)
    end

    local function add_listener(scope, key, listener)
        local key_listeners = listeners[key]
        if not key_listeners then
            listeners[key] = {}
            key_listeners = listeners[key]
        end
        if key_listeners[scope] then
            error "right now only a single listener is supported per scope"
        end
        key_listeners[scope] = listener
        for scope, scoped_data in pairs(data) do
            for key, value in pairs(scoped_data) do
                call_listener(scope, listener, key, value)
            end
        end
    end

    local function del_scope(scope)
        for key, key_listeners in pairs(listeners) do
            key_listeners[scope] = nil
            if not next(key_listeners) then
                listeners[key] = nil
            end
        end

        local scoped_data = data[scope]
        if scoped_data then
            for key, value in pairs(scoped_data) do
                delete(scope, key)
            end
        end
        data[scope] = nil
    end

    return {
        update = update;
        delete = delete;
        add_listener = add_listener;
        del_scope = del_scope;
    }
end

local data = SharedData()

local tile_loader = loader.setup "tile.lua"

tile_loader.before_load = function(tile, exports)
    exports.tcp_clients = tcp_clients
    exports.wait_frame = helper.wait_frame
    exports.wait_t = helper.wait_t
    exports.frame_between = helper.frame_between

    exports.screen = {
        place_video = screen.place_video;
        set_scissor = screen.set_scissor;
        get_rotation = screen.get_rotation;
    }

    exports.clock = schedule_clock;

    exports.update_data = function(key, value)
        data.delete(tile, key)
        data.update(tile, key, value)
    end
    exports.add_listener = function(key, listener)
        data.add_listener(tile, key, listener)
    end
end

tile_loader.unload = function(tile)
    data.del_scope(tile)
end

local function dispatch_to_all_tiles(event, ...)
    for module_name, module in pairs(tile_loader.modules) do
        local fn = module[event]
        if fn then
            local ok, err = xpcall(fn, debug.traceback, ...)
            if not ok then
                log(
                    "dispatch_to_all_tiles", 
                    "cannot dispatch '%s' into '%s': %s",
                    event, module_name, err
                )
            end
        end
    end
end

local kenburns_shader = resource.create_shader[[
    uniform sampler2D Texture;
    varying vec2 TexCoord;
    uniform vec4 Color;
    uniform float x, y, s;
    void main() {
        gl_FragColor = texture2D(Texture, TexCoord * vec2(s, s) + vec2(x, y)) * Color;
    }
]]

local gl_effects = {
    none = function(x1, y1, x2, y2)
        local w, h = x2-x1, y2-y1
        return function(draw, t)
            gl.pushMatrix()
                gl.translate(x1, y1)
                draw(t)
            gl.popMatrix()
        end, w, h
    end,
    rotation = function(x1, y1, x2, y2, config)
        local w, h = x2-x1, y2-y1
        return function(draw, t, starts, ends)
            local effect_easing = config.effect_easing or 'inQuad'
            local effect_rotation = config.effect_rotation or 'y-axis'
            local effect_pivot = config.effect_pivot or 'center'

            local pivot_x, pivot_y = unpack(({
                center = { .5, .5},
                top  =   { .5,  0},
                bottom = { .5,  1},
                left =   {  0, .5},
                right =  {  1, .5},
            })[effect_pivot])

            local enter_t = min(t-starts, 1)
            local exit_t = 1-max(0, 1-(ends-t))
            local effect_value = (
              -easing[effect_easing](1-enter_t, 0, 1, 1) 
              +easing[effect_easing](1-exit_t,  0, 1, 1) 
            )

            gl.pushMatrix()
                gl.translate(x1+w*pivot_x, y1+h*pivot_y)
                if effect_rotation == 'y-axis' then
                    gl.rotate(effect_value*90, 0, 1, 0)
                elseif effect_rotation == 'x-axis' then
                    gl.rotate(effect_value*90, 1, 0, 0)
                end
                gl.translate(-w*pivot_x, -h*pivot_y)
                draw(t)
            gl.popMatrix()
        end, w, h
    end,
    enter_exit_move = function(x1, y1, x2, y2, config)
        local w, h = x2-x1, y2-y1
        return function(draw, t, starts, ends)
            local effect_duration = config.effect_duration or 1
            local effect_easing = config.effect_easing or 'inQuad'
            local effect_direction = config.effect_direction or 'from_left'

            local progress = easing[effect_easing](
                1 - helper.ramp(starts, ends, t, effect_duration),
                0, 1, 1
            )
            local move_x, move_y = unpack(({
                from_left   = {-w,  0},
                from_right  = { w,  0},
                from_bottom = { 0,  h},
                from_top    = { 0, -h},
            })[effect_direction])
            gl.pushMatrix()
                gl.translate(x1+move_x*progress, y1+move_y*progress)
                draw(t)
            gl.popMatrix()
        end, w, h
    end,
}

local function ChildTile(asset, config, x1, y1, x2, y2)
    return function(starts, ends)
        local impl = tile_loader.modules[asset.asset_name]
        return impl.task(starts, ends, config, x1, y1, x2, y2)
    end
end

local function ImageTile(asset, config, x1, y1, x2, y2)
    -- config:
    --   kenburns: true/false
    --   fade_time: 0-1
    --   fit: true/false

    local img = ImageCache.register(asset.asset_name, 10)
    local fade_time = config.fade_time or 0

    return function(starts, ends)
        helper.wait_t(starts - 2)

        -- force loading and keep around for 3 seconds minimum
        img(3)

        local effect, width, height = gl_effects[
            config.effect or 'none'
        ](x1, y1, x2, y2, config)

        local function draw(now)
            if config.fit then
                util.draw_correct(img(), 0, 0, width, height, helper.ramp(
                    starts, ends, now, fade_time
                ))
            else
                img():draw(0, 0, width, height, helper.ramp(
                    starts, ends, now, fade_time
                ))
            end
        end

        if config.kenburns then
            local function lerp(s, e, t)
                return s + t * (e-s)
            end

            local paths = {
                {from = {x=0.0,  y=0.0,  s=1.0 }, to = {x=0.08, y=0.08, s=0.9 }},
                {from = {x=0.05, y=0.0,  s=0.93}, to = {x=0.03, y=0.03, s=0.97}},
                {from = {x=0.02, y=0.05, s=0.91}, to = {x=0.01, y=0.05, s=0.95}},
                {from = {x=0.07, y=0.05, s=0.91}, to = {x=0.04, y=0.03, s=0.95}},
            }

            local path = paths[math.random(1, #paths)]

            local to, from = path.to, path.from
            if math.random() >= 0.5 then
                to, from = from, to
            end

            local w, h = img():size()
            local duration = ends - starts

            local function lerp(s, e, t)
                return s + t * (e-s)
            end

            for now in helper.frame_between(starts, ends) do
                local t = (now - starts) / duration
                kenburns_shader:use{
                    x = lerp(from.x, to.x, t);
                    y = lerp(from.y, to.y, t);
                    s = lerp(from.s, to.s, t);
                }
                effect(draw, now, starts, ends)
                kenburns_shader:deactivate()
            end
        else
            for now in helper.frame_between(starts, ends) do
                effect(draw, now, starts, ends)
            end
        end
    end
end

local transparent_shader = resource.create_shader[[
    uniform sampler2D Texture;
    varying vec2 TexCoord;
    uniform vec3 Transparent;
    uniform vec4 Color;

    // These values seem to work reasonably well.
    const float thresholdSensitivity = 0.15;
    const float smoothing = 0.3;

    void main() {
        vec3 col = texture2D(Texture, TexCoord).rgb;
        float maskY = 0.2989 * Transparent.r + 0.5866 * Transparent.g + 0.1145 * Transparent.b;
        float maskCr = 0.7132 * (Transparent.r - maskY);
        float maskCb = 0.5647 * (Transparent.b - maskY);

        float Y = 0.2989 * col.r + 0.5866 * col.g + 0.1145 * col.b;
        float Cr = 0.7132 * (col.r - Y);
        float Cb = 0.5647 * (col.b - Y);

        float blendValue = smoothstep(thresholdSensitivity, thresholdSensitivity + smoothing, distance(vec2(Cr, Cb), vec2(maskCr, maskCb)));

        gl_FragColor = vec4(col * blendValue, 1.0 * blendValue);
    }
]]

local function VideoTile(asset, config, x1, y1, x2, y2)
    -- config:
    --   fade_time: 0-1
    --   looped
    --   transparency: bool
    --   transparent_color: #ffffff

    local file = resource.open_file(asset.asset_name)
    local fade_time = config.fade_time or 0.5
    local looped = config.looped
    local audio = config.audio

    local transparency = config.transparency
    local r, g, b = helper.parse_rgb(config.transparent_color or "#ffffff")
    local shader_args = {
        Transparent = {r, g, b}
    }

    return function(starts, ends)
        helper.wait_t(starts - 2)

        local vid = resource.load_video{
            file = file,
            paused = true,
            looped = looped,
            audio = audio,
        }

        for now in helper.frame_between(starts, ends) do
            if transparency then
                transparent_shader:use(shader_args)
            end
            vid:draw(x1, y1, x2, y2, helper.ramp(
                starts, ends, now, fade_time
            )):start()
            if transparency then
                transparent_shader:deactivate()
            end
        end

        vid:dispose()
    end
end

local function RawVideoTile(asset, config, x1, y1, x2, y2)
    -- config:
    --   asset_name: 'foo.mp4'
    --   fit: aspect fit or scale?
    --   fade_time: 0-1
    --   looped
    --   layer: video layer for raw videos

    local file = resource.open_file(asset.asset_name)
    local fade_time = config.fade_time or 0.5
    local looped = config.looped
    local audio = config.audio
    local layer = config.layer or 5

    return function(starts, ends)
        helper.wait_t(starts - 2)

        local vid = resource.load_video{
            file = file,
            paused = true,
            looped = looped,
            audio = audio,
            raw = true,
        }
        vid:layer(-10)

        for now in helper.frame_between(starts, ends) do
            screen.place_video(vid, layer, helper.ramp(
                starts, ends, now, fade_time
            ), x1, y1, x2, y2):start()
        end

        vid:dispose()
    end
end

local function Streams()
    local frame = 0
    local streams = {}

    local MIN_LOAD_INTERVAL = 5
    local LOADING_TIMEOUT = 10

    local function stream_key(url, audio)
        return string.format("%s|%s", url, audio)
    end

    local function get_stream(url, audio)
        local key = stream_key(url, audio)
        if not streams[key] then
            -- Initialize the stream only once
            streams[key] = {
                vid = resource.load_video{
                    file = url,
                    audio = audio,
                    raw = true,
                },
                last_used = frame,
                url = url,  -- Store URL for debugging
            }
            -- Keep stream running but hidden
            streams[key].vid:layer(-10):place(0, 0, 0, 0):alpha(0):start()
        end

        streams[key].last_used = frame
        return streams[key].vid
    end

    local function tick()
        frame = frame + 1
        if frame % 300 == 0 then
            print "[stream] active streams"
            pp(streams)
        end

        for key, stream in pairs(streams) do
            local frame_delta = frame - stream.last_used
            -- Increase this value significantly, maybe 300 frames or more
            if frame_delta > 300 then  -- About 5 seconds at 60fps
                print("[stream] disposing stream", stream.url)
                if stream.vid then
                    stream.vid:dispose()
                end
                streams[key] = nil
            end
        end
    end

    return {
        get_stream = get_stream;
        tick = tick;
    }
end
local streams = Streams()

local function StreamTile(asset, config, x1, y1, x2, y2)
    local layer = config.layer or 5
    local url = config.url or ""
    local audio = config.audio

    return function(starts, ends)
        -- player
        for now in helper.frame_between(starts, ends) do
            local vid = streams.get_stream(url, audio)
            if vid then
                screen.place_video(vid, layer, 1, x1, y1, x2, y2)
            end
        end
    end
end

local function FlatTile(asset, config, x1, y1, x2, y2)
    -- config:
    --   color: "#rrggbb"
    --   fade_time: 0-1

    local r, g, b = helper.parse_rgb(config.color or "#ffffff")
    local a = (config.alpha or 255)/255

    local flat = resource.create_colored_texture(r, g, b, a)
    local fade_time = config.fade_time or 0.5

    return function(starts, ends)
        for now in helper.frame_between(starts, ends) do
            flat:draw(x1, y1, x2, y2, helper.ramp(
                starts, ends, now, fade_time
            ))
        end
        flat:dispose()
    end
end

local function CountdownTile(asset, config, x1, y1, x2, y2)
    local target = config.target
    local type = config.type or "hms"
    local r, g, b = helper.parse_rgb(config.color or "#333333")
    local align = config.align or "center"
    local mode = config.mode or "countdown"
    local size = y2 - y1
    local font = ({
        default = font_regl,
        digital = font_7seg,
    })[config.font or "default"]
    local fmt = ({
        german = {
            dh = "%d Tag(e), %d Std.",
            hms = "%d Std %d Min %d Sek",
            ms = "%d Min %d Sek",
            hm = "%d Std %d Min",
        },
        english = {
            dh = "%d day(s), %dh",
            hms = "%dh %dm %ds",
            ms = "%dm %ds",
            hm = "%dh %dm",
        },
        none = {
            hms = "%d:%02d:%02d",
            ms = "%d:%02d",
            hm = "%d:%02d",
        },
    })[config.locale or "english"]

    return function(starts, ends)
        for now in helper.frame_between(starts, ends) do
            local delta = Countdowns.delta(target)

            delta = ceil(delta)

            if mode == "countdown" then
                delta = max(0, delta)
            elseif mode == "countup" then
                delta = min(0, delta)
            end

            delta = abs(delta)

            local text
            if type == "hms" then
                text = string.format(fmt.hms,
                    math.floor(delta / 3600),
                    math.floor(delta % 3600 / 60),
                    math.floor(delta % 60)
                )
            elseif type == "hm" then
                text = string.format(fmt.hm,
                    math.floor(delta / 3600),
                    math.floor(delta % 3600 / 60)
                )
            elseif type == "adaptive_dhm" then
                if abs(delta) > 86400 then
                    text = string.format(fmt.dh,
                        math.floor(delta / 86400),
                        math.floor(delta % 86400 / 3600)
                    )
                elseif abs(delta) > 120 * 60 then
                    text = string.format(fmt.hms,
                        math.floor(delta / 3600),
                        math.floor(delta % 3600 / 60),
                        math.floor(delta % 60)
                    )
                else
                    text = string.format(fmt.ms,
                        math.floor(delta / 60),
                        math.floor(delta % 60)
                    )
                end
            elseif type == "adaptive_hms" then
                if abs(delta) > 120 * 60 then
                    text = string.format(fmt.hms,
                        math.floor(delta / 3600),
                        math.floor(delta % 3600 / 60),
                        math.floor(delta % 60)
                    )
                else
                    text = string.format(fmt.ms,
                        math.floor(delta / 60),
                        math.floor(delta % 60)
                    )
                end
            end

            local w = font:width(text, size)

            local x
            if align == "left" then
                x = x1
            elseif align == "right" then
                x = x2 - w
            elseif align == "center" then
                x = x1 + (x2-x1)/2 - w/2
            end

            font:write(x, y1, text, size, r,g,b,1)
        end
    end
end

local function TimeTile(asset, config, x1, y1, x2, y2)
    local r, g, b = helper.parse_rgb(config.color or "#333333")
    local clock = clock_for_tz_or_default(json_nullify(config.timezone))

    local clock_mode = config.mode or "digital_clock"
    local clock_type = config.type or "hms"
    local clock_style = config.style or 1
    local clock_align = config.align or "center"
    local clock_movement = config.movement or "dynamic"

    if clock_mode == "digital_clock" then
        local size = y2 - y1

        local font
        if clock_style == 1 then
            font = font_7seg
        else
            font = font_regl
        end

        local formatter
        if clock_type == "hm" then
            formatter = function(t)
                return string.format("%02d:%02d",
                    math.floor(t / 3600),
                    math.floor(t % 3600 / 60)
                ), '99:99', ''
            end
        elseif clock_type == "hms" then
            formatter = function(t)
                return string.format("%02d:%02d:%02d",
                    math.floor(t / 3600),
                    math.floor(t % 3600 / 60),
                    math.floor(t % 60)
                ), '99:99:99', ''
            end
        elseif clock_type == "hm_12" then
            formatter = function(t)
                local hours = math.floor(t / 3600)
                local minutes = math.floor(t % 3600 / 60)
                local ampm = "am"
                if hours >= 12 then
                    ampm = "pm"
                    hours = hours - 12
                end
                if hours == 0 then
                    hours = 12
                end
                return string.format("%02d:%02d",
                    hours, minutes
                ), '99:99', ' '..ampm
            end
        elseif clock_type == "hms_12" then
            formatter = function(t)
                local hours = math.floor(t / 3600)
                local minutes = math.floor(t % 3600 / 60)
                local seconds = math.floor(t % 60)
                local ampm = "am"
                if hours >= 12 then
                    ampm = "pm"
                    hours = hours - 12
                end
                if hours == 0 then
                    hours = 12
                end
                return string.format("%02d:%02d:%02d",
                    hours, minutes, seconds
                ), '99:99:99', ' '..ampm
            end
        end

        return function(starts, ends)
            for now in helper.frame_between(starts, ends) do
                local time, tmpl, suffix = formatter(clock.since_midnight())

                local w_time = font:width(tmpl, size)
                local w = w_time + font:width(suffix, size)

                local x
                if clock_align == "left" then
                    x = x1
                elseif clock_align == "right" then
                    x = x2 - w
                elseif clock_align == "center" then
                    x = x1 + (x2-x1)/2 - w/2
                end

                font:write(x, y1, time, size, r,g,b,1)
                x = x + w_time
                font:write(x, y1, suffix, size, r,g,b,1)
            end
        end
    elseif clock_mode == "analog_clock" then
        local cx = x1 + (x2 - x1)/2
        local cy = y1 + (y2 - y1)/2
        local size = math.min(y2-y1, x2-x1)
        local radius = size/2
        local unit = size/30

        local hand_img
        
        if clock_style == 1 then 
            hand_img = resource.load_image{
                file = "hand-1.png",
                mipmap = true,
            }
        else
            hand_img = resource.load_image{
                file = "hand-2.png",
                mipmap = true,
            }
        end

        local show_seconds = clock_type == "hms" or clock_type == "hms_12"

        -- local function dots()
        --     gl.pushMatrix()
        --         gl.rotate(90, 0, 0, 1)
        --         for i = 0, 55,5 do
        --             if i % 15 == 0 then
        --                 pixel:draw(radius-unit, -unit/2, radius, unit/2, 0.8)
        --             else 
        --                 pixel:draw(radius-unit/2, -unit/4, radius, unit/4, 0.8)
        --             end
        --             gl.rotate(360/60*5, 0, 0, 1)
        --         end
        --     gl.popMatrix()
        -- end

        local function hand(len, thick, angle)
            gl.pushMatrix()
                gl.rotate(angle*360-90, 0, 0, 1)
                hand_img:draw(-len*0.1, -thick/2, len*0.9, thick/2)
            gl.popMatrix()
        end

        local function movement(val)
            if clock_movement == "dynamic" then
                return math.floor(val) + math.sin(((val%1)-0.5) * math.pi)/2 + .5
            elseif clock_movement == "smooth" then
                return val
            else
                return math.floor(val)
            end
        end

        return function(starts, ends)
            for now in helper.frame_between(starts, ends) do
                local t = clock.since_midnight()

                colored:use{
                    color = {r,g,b,1}
                }
                gl.pushMatrix()
                    gl.translate(cx, cy)

                    local hour = movement((t / 3600) % 12)
                    hand(radius-7*unit, unit, hour/12)

                    local minute = movement(t % 3600 / 60)
                    hand(radius-3*unit, unit*0.75, minute/60)

                    if show_seconds then
                        local second = movement(t % 60)
                        hand(radius, unit*0.5, second/60)
                    end
                gl.popMatrix()
                colored:deactivate()
            end
            hand_img:dispose()
        end
    end
end

local function MarkupTile(asset, config, x1, y1, x2, y2)
    local fade_time = config.fade_time or 0
    local text = config.text or ""
    local font_size = config.font_size or 35
    local align = config.align or "tl"
    local font = FontCache.get(asset.asset_name)

    local width = x2 - x1
    local height = y2 - y1
    local r, g, b = helper.parse_rgb(config.color or "#ffffff")

    local y = 0
    local max_x = 0
    local writes = {}

    local cell_padding = 40
    local paragraph_split = 40
    local line_height = 1.05

    local default_font_size = font_size
    local h1_font_size = default_font_size * 2
    local h2_font_size = floor(h1_font_size * 0.75)

    local function max_per_line(font, size, width)
        -- try to calculate the max characters/line
        -- number based on the average character width
        -- of the specified font.
        local test_width = font:width("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz", size)
        local avg_width = test_width / 52
        local chars_per_line = width / avg_width
        return floor(chars_per_line)
    end

    local rows = {}
    local function flush_table()
        local max_w = {}
        for ri = 1, #rows do
            local row = rows[ri]
            for ci = 1, #row do
                local col = row[ci]
                max_w[ci] = max(max_w[ci] or 0, col.width)
            end
        end

        local TABLE_SEPARATE = 40

        for ri = 1, #rows do
            local row = rows[ri]
            local x = 0
            for ci = 1, #row do
                local col = row[ci]
                if col.text ~= "" then
                    col.x = floor(x)
                    col.y = floor(y)
                    writes[#writes+1] = col
                end
                x = x + max_w[ci]+cell_padding
            end
            y = y + default_font_size * line_height
            max_x = max(max_x, x-cell_padding)
        end
        rows = {}
    end

    local function add_row()
        local cols = {}
        rows[#rows+1] = cols
        return cols
    end

    local function layout_paragraph(paragraph)
        for line in string.gmatch(paragraph, "[^\n]+") do
            local size = default_font_size -- font size for line
            local maxl = max_per_line(font, size, width)

            if line:find "|" then
                -- table row
                local cols = add_row()
                for field in line:gmatch("[^|]+") do
                    field = helper.trim(field)
                    local width = font:width(field, size)
                    cols[#cols+1] = {
                        font = font,
                        text = field,
                        size = size,
                        width = width,
                    }
                end
            else
                -- plain text, wrapped
                flush_table()

                -- markdown header # and ##
                if line:sub(1,2) == "##" then
                    line = line:sub(3)
                    font = font
                    size = h2_font_size
                    maxl = max_per_line(font, size, width)
                elseif line:sub(1,1) == "#" then
                    line = line:sub(2)
                    font = font
                    size = h1_font_size
                    maxl = max_per_line(font, size, width)
                end

                local chunks = helper.wrap(line, maxl)
                for idx = 1, #chunks do
                    local chunk = chunks[idx]
                    chunk = helper.trim(chunk)
                    writes[#writes+1] = {
                        font = font,
                        x = 0,
                        y = floor(y),
                        text = chunk,
                        size = size,
                    }
                    local width = font:width(chunk, size)
                    y = y + size * line_height
                    max_x = max(max_x, width)
                end
            end
        end

        flush_table()
    end

    local paragraphs = helper.split(text, "\n\n")
    for idx = 1, #paragraphs do
        local paragraph = paragraphs[idx]
        paragraph = paragraph:gsub("\t", " ")
        layout_paragraph(paragraph)
        y = y + paragraph_split
    end

    -- remove one split
    local max_y = y - paragraph_split
    local base_x, base_y

    if align == "tl" then
        base_x = 0
        base_y = 0
    elseif align == "center" then
        base_x = floor((width-max_x) / 2)
        base_y = floor((height-max_y) / 2)
    end

    return function(starts, ends)
        for now in helper.frame_between(starts, ends) do
            local x = x1 + base_x
            local y = y1 + base_y
            for idx = 1, #writes do
                local w = writes[idx]
                w.font:write(x+w.x, y+w.y, w.text, w.size, r,g,b,helper.ramp(
                    starts, ends, now, fade_time
                ))
            end
        end
    end
end

local function JobQueue()
    local jobs = {}

    local function add(fn, starts, ends)
        local co = coroutine.create(fn)
        local ok, again = coroutine.resume(co, starts, ends)
        if not ok then
            log(
                "jobqueue",
                "cannot create task:\n%s\n%s\ninside coroutine started by",
                again, debug.traceback(co)
            )
        elseif not again then
            return
        end

        local job = {
            starts = starts,
            ends = ends,
            co = co,
        }

        jobs[#jobs+1] = job
    end

    local function tick(now)
        for idx, job in ipairs(jobs) do
            local ok, again = coroutine.resume(job.co, now)
            if not ok then
                log(
                    "jobqueue",
                    "cannot run task:\n%s\n%s\ninside coroutine %s resumed by",
                    again, debug.traceback(job.co), job
                )
                job.done = true
            elseif not again then
                job.done = true
            end
        end

        -- iterate backwards so we can remove finished jobs
        for idx = #jobs,1,-1 do
            local job = jobs[idx]
            if job.done then
                table.remove(jobs, idx)
            end
        end
    end

    local function flush()
        jobs = {}
        node.gc()
    end

    return {
        tick = tick;
        add = add;
        flush = flush;
    }
end

local layouts = {}
local background = {r = 0, g = 0, b = 0, a = 0}
local current_setup_id = "UNKNOWN_SETUP" 

node.event("config_updated", function(config)
    layouts = config.layouts
    for _, layout in ipairs(layouts) do
        for _, tile in ipairs(layout.tiles) do
            local asset = tile.asset
            if asset.type == "image" or asset.type == "video" then
                log("config_updated", "fixing layout asset %s", asset.asset_name)
                asset.asset_name = resource.open_file(asset.asset_name)
            end
        end
    end
    background = config.background
    
    -- Store the setup_id when config is updated
    if config.__metadata and config.__metadata.setup_id then
        current_setup_id = config.__metadata.setup_id
        log("config_updated", "Stored setup_id: %s", current_setup_id)
    else
        log("config_updated", "setup_id not found in config metadata")
    end
end)

local function Page(page)
    local function get_duration(playback_mode)
        local duration = page.duration
        if duration == 0 then
            for _, tile in ipairs(page.tiles) do
                if tile.asset.metadata and tile.asset.metadata.duration then
                    duration = max(duration, tile.asset.metadata.duration)
                elseif tile.type == "child" then
                    local child_name = tile.asset.asset_name
                    local impl = tile_loader.modules[child_name]
                    if impl.auto_duration then
                        duration = max(duration, impl.auto_duration())
                    end
                end
            end
            if duration == 0 then
                duration = 10
            else
                duration = math.max(2, duration)
            end
            print("automatically set auto duration is", duration)
        end
        if playback_mode == "interactive" and page.interaction.duration == "forever" then
            duration = "forever"
        end
        return duration
    end

    local function can_show()
        local can_show = true
        for _, tile in ipairs(page.tiles) do
            if tile.type == "child" then
                local child_name = tile.asset.asset_name
                local impl = tile_loader.modules[child_name]
                if impl.can_show and not impl.can_show(tile.config) then
                    print("probing child tile", child_name, "can_show==false")
                    can_show = false
                end
            end
        end
        return can_show
    end

    local function get_tiles()
        local tiles = {}

        local function append_page_tiles()
            for _, tile in ipairs(page.tiles) do
                tiles[#tiles+1] = tile
            end
        end

        local layout = layouts[page.layout_id+1]
        if not layout then
            append_page_tiles()
        else
            for _, tile in ipairs(layout.tiles) do
                if tile.type == "page" then
                    append_page_tiles()
                else
                    tiles[#tiles+1] = tile
                end
            end
        end
        return tiles
    end

    return {
        get_duration = get_duration;
        get_tiles = get_tiles;
        is_fallback = page.is_fallback;
        can_show = can_show;
    }
end

local function Scheduler(page_source, job_queue)
    local SCHEDULE_LOOKAHEAD = 2

    local scheduled_until = sys.now()

    local showing_fallback = false
    local scheduled_forever = false

    local function enqueue_page(page, playback_mode)
        playback_mode = playback_mode or "default"

        local duration = page.get_duration(playback_mode)

        local starts = scheduled_until
        local ends

        if duration == "forever" then
            -- more than 1000 days, so close enough
            ends = starts + 100000000

            -- If a 'forever' page is scheduled, note that this
            -- is the case, so the config watcher can use this
            -- in its decision on whether or not to reset the
            -- scheduled jobs.
            scheduled_forever = true
        else
            ends = starts + duration
        end

        local next_layer = {
            back = -10,
            front = 1,
        }

        local tiles = page.get_tiles()
        for n, tile in ipairs(tiles) do
            local handler = ({
                image = ImageTile,
                video = VideoTile,
                rawvideo = RawVideoTile,
                stream = StreamTile,
                child = ChildTile,
                flat = FlatTile,
                time = TimeTile,
                countdown = CountdownTile,
                markup = MarkupTile,
            })[tile.type]

            -- Reorder layering, so that layers back and front
            -- layers are sorted by their tile order.
            if tile.type == 'rawvideo' or tile.type == 'stream' then
                local old_layer = tile.config.layer or 5
                local next_layer_select = old_layer < 0 and "back" or "front"
                tile.config.layer = next_layer[next_layer_select]
                next_layer[next_layer_select] = next_layer[next_layer_select] + 1
            end

            -- print "adding tile"
            job_queue.add(
                handler(tile.asset, tile.config, tile.x1, tile.y1, tile.x2, tile.y2),
                starts, ends
            )
        end

        job_queue.add(
            function(starts, ends)
                helper.wait_t(starts)
                showing_fallback = page.is_fallback
                tcp_clients.send(
                    "root/__fallback__",
                    page.is_fallback and "1" or "0"
                )
            end,
            starts, ends
        )

        scheduled_until = ends
    end

    local function tick(now)
        if now < scheduled_until - SCHEDULE_LOOKAHEAD then
            return
        end

        enqueue_page(page_source.get_next())
    end

    local function reset_scheduler()
        job_queue.flush()
        scheduled_forever = false
        scheduled_until = sys.now()
    end

    local function enqueue_interactive(pages)
        reset_scheduler()
        for i, page in ipairs(pages) do
            enqueue_page(page, "interactive")
        end
    end

    local function handle_keyboard(event)
        -- if event.action ~= "down" and event.action ~= "hold" then
        if event.action ~= "down" then
            return
        end

        if event.key == "esc" then
            reset_scheduler()
            -- Hide all QR codes on ESC
            for id, instance in pairs(qr_code_instances) do
                instance.is_visible = false
                print("Hiding QR instance " .. id .. " due to ESC")
            end
            return
        end

        -- Hide QR codes on arrow key navigation
        if event.key == "left" or event.key == "right" then
            for id, instance in pairs(qr_code_instances) do
                instance.is_visible = false
                print("Hiding QR instance " .. id .. " due to keyboard navigation")
            end
        end

        if event.key == "left" then
            reset_scheduler()
            enqueue_page(page_source.get_prev())
            return
        end

        if event.key == "right" then
            reset_scheduler()
            enqueue_page(page_source.get_next())
            return
        end

        local pages = page_source.find_by_key(event.key)
        if not pages then
            return
        end
        enqueue_interactive(pages)
    end

    local function handle_gamepad(event)
        local pages = page_source.find_by_key(event.key)
        if not pages then
            return
        end
        enqueue_interactive(pages)
    end

    local function handle_gpio(event)
        local pages = page_source.find_by_gpio(event.pin)
        if not pages then
            return
        end
        enqueue_interactive(pages)
    end

    local function handle_remote_trigger(trigger_data)
        print("Remote trigger received:", trigger_data)

        local qr_instance_updated = false

        -- Check if this trigger_data corresponds to any predefined QR instance's trigger_data
        for id, instance in pairs(qr_code_instances) do
            if instance.trigger_data == trigger_data then
                print("Trigger " .. trigger_data .. " matches predefined QR instance: " .. id)
                local new_draw_details = qrcode_overlay.handle_remote_trigger(instance.trigger_data, current_setup_id)
                if new_draw_details then
                    instance.draw_details = new_draw_details
                    instance.is_visible = true
                    qr_instance_updated = true
                    print("Activated and updated QR instance: " .. id)
                else
                    print("ERROR: Failed to get draw details for QR instance: " .. id .. " (trigger: " .. trigger_data .. ")")
                    instance.is_visible = false -- Hide if generation fails
                    instance.draw_details = nil
                end
                -- If you want a trigger to only activate ONE specific QR code and hide others,
                -- you might add logic here to set other_instance.is_visible = false
                -- For now, a trigger activates its corresponding QR without affecting others that might be visible.
            end
        end

        -- If no QR instance was specifically updated by this trigger, 
        -- AND this trigger is not one of the known QR generation triggers for predefined instances,
        -- then hide all QR codes. This prevents unrelated triggers from leaving QR codes on screen.
        local is_known_qr_gen_trigger = false
        for _, instance in pairs(qr_code_instances) do
            if instance.trigger_data == trigger_data then
                is_known_qr_gen_trigger = true
                break
            end
        end

        if not qr_instance_updated and not is_known_qr_gen_trigger then
            print("Trigger '" .. trigger_data .. "' is not a specific QR activation trigger. Hiding all QR instances.")
            for id, instance in pairs(qr_code_instances) do
                instance.is_visible = false
            end
        end

        -- Process normal page navigation using the scheduler
        local pages = page_source.find_by_remote(trigger_data)
        if not pages then
            -- If not a page navigation trigger either, and we didn't update a QR, it might be an unhandled trigger.
            -- The 'hiding all' logic above should cover making sure QRs don't persist incorrectly.
            return false -- Indicate trigger was not fully handled for page navigation
        end
        enqueue_interactive(pages)
        return true
    end

    local function handle_cec(cec_key)
        -- Hide QR codes on CEC navigation
        if cec_key == "left" or cec_key == "right" then
            for id, instance in pairs(qr_code_instances) do
                instance.is_visible = false
                print("Hiding QR instance " .. id .. " due to CEC navigation")
            end
        end

        if cec_key == "left" then
            reset_scheduler()
            enqueue_page(page_source.get_prev())
            return
        end

        if cec_key == "right" then
            reset_scheduler()
            enqueue_page(page_source.get_next())
            return
        end
    end

    local last_setup_id, last_config_hash

    node.event("config_updated", function(config)
        local setup_id = config.__metadata.setup_id
        local config_hash = config.__metadata.config_hash
        local reset_mode = config.reset_mode

        local force_reset

        if reset_mode == "config" then
            force_reset = config_hash ~= last_config_hash
        elseif reset_mode == "setup" then
            force_reset = setup_id ~= last_setup_id
        elseif reset_mode == "in_forever" then
            force_reset = scheduled_forever and config_hash ~= last_config_hash
        else -- "none"
            force_reset = false
        end

        if force_reset then
            print("config updated: forcing scheduler reset")
            reset_scheduler()
        end

        last_setup_id = setup_id
        last_config_hash = config_hash
    end)

    return {
        tick = tick;
        handle_keyboard = handle_keyboard;
        handle_gamepad = handle_gamepad;
        handle_gpio = handle_gpio;
        handle_remote_trigger = handle_remote_trigger;
        handle_cec = handle_cec;
    }
end

local function PageSource()
    local schedules = {}

    local cycle_pages = {}
    local cycle_offset = 0

    local find_offset = 0

    local fallback
    local debug_schedule_id, debug_page_id
    local trigger = "next"

    node.event("config_updated", function(config)
        schedules = config.schedules

        for _, schedule in ipairs(schedules) do
            for _, page in ipairs(schedule.pages) do
                page.is_fallback = false
                if page.duration == -1 then
                    -- disabled page? then remove it
                    table.remove(schedule.pages, page_id)
                else
                    for _, tile in ipairs(page.tiles) do
                        local asset = tile.asset
                        if asset.type == "image" or asset.type == "video" then
                            log("config_updated", "fixing schedule asset %s", asset.asset_name)
                            asset.asset_name = resource.open_file(asset.asset_name)
                        end
                    end
                end
            end
        end

        debug_schedule_id = config.scratch.debug_schedule_id
        debug_page_id = config.scratch.debug_page_id
        fallback = config.fallback
        trigger = config.trigger
    end)

    local function date_within(starts, ends, test)
        local function expand(date)
            return date.year * 600 + date.month * 40 + date.day
        end
        local t = expand(test)
        local s = 0
        if starts then
            s = expand(starts)
        end
        local e = 100000000
        if ends then
            e = expand(ends)
        end
        return t >= s and t <= e
    end

    local function parse_date(d)
        if not d then
            return nil
        end
        local year, month, day = d:match "(%d+)-(%d+)-(%d+)"
        if not year then
            return nil
        end
        return {year=tonumber(year), month=tonumber(month), day=tonumber(day)}
    end

    local function parse_hour(h)
        local hour, minute = h:match "(%d+):(%d+)"
        return {hour=tonumber(hour), minute=tonumber(minute)}
    end

    local function minutes_since_midnight(t)
        return t.hour * 60 + t.minute
    end

    local function is_scheduled(schedule)
        local scheduling = schedule.scheduling
        local mode = scheduling.mode or "span"
        local starts = parse_date(scheduling.starts)
        local ends = parse_date(scheduling.ends)

        if mode == "fallback" then
            -- Do not schedule here. Later if there's nothing scheduled at all, we
            -- fetch the 'fallback' schedules in get_fallback_cycle()
            return false
        elseif mode == "always" then
            return true
        elseif mode == "never" then
            return false
        end

        if not schedule_clock.has_time() then
            if starts or ends then
                log("schedule", "no current time. can't schedule playlist with start/end date")
                return false
            end
            if mode == "hour" then
                local hours = scheduling.hours or {}
                for hour = 1, 24*7+1 do
                    -- see if all hours are unchecked. If any is checked,
                    -- we can't schedule as we need to know the current
                    -- hour.
                    if hours[hour+1] == false then
                        log("schedule", "no current time. can't schedule hour based playlist")
                        return false
                    end
                end
            elseif mode == "span" then
                local spans = scheduling.spans or {}
                -- If a timestamp is set, we can't schedule.
                if #spans > 0 then
                    log("schedule", "no current time. can't schedule span scheduled playlist")
                    return false
                end
            elseif mode == "interval" then
                log("schedule", "no current time. can't schedule playlist with time interval")
                return false
            end
            log("schedule", "scheduling although we don't have a correct time as schedule is always active")
            return true
        end

        local today = schedule_clock.today()

        if not date_within(starts, ends, today) then
            log("schedule", "outside of scheduled dates. can't schedule")
            return false
        end

        if mode == "hour" then
            local current_hour = schedule_clock.week_hour()
            local hours = scheduling.hours or {}
            if hours[current_hour+1] == false then
                -- only refuse to schedule if it's actually set to 'false'.
                -- nil means that the hours list is empty which implicitly
                -- means: "always show".
                log("schedule", "not within the current week hour. can't schedule")
                return false
            else
                return true
            end
        elseif mode == "span" then
            local spans = scheduling.spans or {}

            if #spans == 0 then
                log("schedule", "no spans. always schedule")
                return true
            end

            local since_midnight = schedule_clock.since_midnight()
            for span_id, span in ipairs(spans) do
                local dow = schedule_clock.day_of_week()
                if span.days[dow+1] then
                    local start_sec = minutes_since_midnight(parse_hour(span.starts)) * 60
                    local end_sec = minutes_since_midnight(parse_hour(span.ends)) * 60 + 60
                    if since_midnight >= start_sec and since_midnight < end_sec then
                        log("schedule", "span %s matches", span_id)
                        return true
                    end
                end
            end
            return false
        elseif mode == "interval" then
            local interval = scheduling.interval or {}
            local interval_starts = interval.starts or "00:00"
            local interval_ends = interval.ends or "23:59"
            local since_midnight = schedule_clock.since_midnight()

            if date_within(starts, starts, today) and
               since_midnight < minutes_since_midnight(parse_hour(interval_starts)) * 60
            then
                return false
            end

            if date_within(ends, ends, today) and
               since_midnight > minutes_since_midnight(parse_hour(interval_ends)) * 60 + 59
            then
                return false
            end

            log("schedule", "interval matches")
            return true
        end
    end

    local function select_next_find(pages)
        find_offset = find_offset + 1
        if find_offset > #pages then
            find_offset = 1
        end
        return pages[find_offset]
    end

    local function triggered_pages(pages)
        if #pages == 0 then
            return
        end
        if trigger == "next" then
            return {select_next_find(pages)}
        else
            return pages
        end
    end

    local function find_by_key(key)
        local pages = {}
        for schedule_id, schedule in ipairs(schedules) do
            for page_id, page in ipairs(schedule.pages) do
                if page.interaction.key == key then
                    pages[#pages+1] = Page(page)
                end
            end
        end
        return triggered_pages(pages)
    end

    local function find_by_gpio(pin)
        local pages = {}
        local key = string.format("gpio_%d", pin)
        for schedule_id, schedule in ipairs(schedules) do
            for page_id, page in ipairs(schedule.pages) do
                if page.interaction.key == key then
                    pages[#pages+1] = Page(page)
                end
            end
        end
        return triggered_pages(pages)
    end

    local function find_by_remote(remote)
        local pages = {}
        for schedule_id, schedule in ipairs(schedules) do
            for page_id, page in ipairs(schedule.pages) do
                if page.interaction.key == 'remote' and page.interaction.remote == remote then
                    pages[#pages+1] = Page(page)
                end
            end
        end
        return triggered_pages(pages)
    end

    local function get_page(schedule_id, page_id)
        local schedule = schedules[schedule_id]
        if not schedule then
            return
        end

        local page = schedule.pages[page_id]
        if not page then
            return
        end

        return Page(page)
    end

    local function get_debug_page()
        if debug_schedule_id and debug_page_id then
            return get_page(debug_schedule_id+1, debug_page_id+1)
        end
    end

    local function fill_pages_from_schedule(pages, schedule)
        local filtered_pages = {}
        for i, page in ipairs(schedule.pages) do
            page = Page(page)
            if page.can_show() then
                filtered_pages[#filtered_pages+1] = page
            end
        end

        print("filtered pages:", #filtered_pages)

        if #filtered_pages == 0 then
            return
        end

        local display_mode = schedule.display_mode or "all"

        -- take all pages
        if display_mode == "all" then
            log("schedule", "adding all pages")
            for p = 1, #filtered_pages do
                pages[#pages+1] = filtered_pages[p]
            end
            return
        end

        -- randomly select some/all from filtered pages
        local sample = ({
            ["random-1"] = 1,
            ["random-2"] = 2,
            ["random-3"] = 3,
            ["random-4"] = 4,
            ["random-5"] = 5,
            ["random-6"] = 6,
            ["random-all"] = 100000,
        })[display_mode]
        sample = math.min(sample, #filtered_pages)
        log("schedule", "selecting %d random pages", sample)
        permute(filtered_pages)
        for p = 1, sample do
            pages[#pages+1] = filtered_pages[p]
        end
    end

    local function get_scheduled_pages()
        local pages = {}
        for schedule_id, schedule in ipairs(schedules) do
            log("schedule", "checking schedule %s (%d)", schedule.name, schedule_id)
            if is_scheduled(schedule) then
                fill_pages_from_schedule(pages, schedule)
            end
        end
        return pages
    end

    local function get_fallback_cycle()
        local pages = {}
        for schedule_id, schedule in ipairs(schedules) do
            if schedule.scheduling.mode == "fallback" then
                fill_pages_from_schedule(pages, schedule)
            end
        end

        if #pages > 0 then
            log("get_fallback_cycle", "added %d pages scheduled as fallback", #pages)
        else
            if fallback.type == "image" then
                pages[#pages+1] = Page{
                    is_fallback = true,
                    duration = 5,
                    auto_duration = 5,
                    layout_id = -1,
                    overlap = 0,
                    tiles = {{
                        x1 = 0,
                        y1 = 0,
                        x2 = WIDTH,
                        y2 = HEIGHT,
                        asset = fallback,
                        type = 'image',
                        config = {
                            fit = true,
                        }
                    }}
                }
            else
                local duration = 5
                if fallback.metadata and fallback.metadata.duration then
                    duration = fallback.metadata.duration
                end
                pages[#pages+1] = Page{
                    is_fallback = true,
                    duration = duration,
                    auto_duration = duration,
                    layout_id = -1,
                    overlap = 0,
                    tiles = {{
                        x1 = 0,
                        y1 = 0,
                        x2 = WIDTH,
                        y2 = HEIGHT,
                        asset = fallback,
                        type = 'rawvideo',
                        config = {
                            audio = true,
                        }
                    }}
                }
            end
        end
        log("schedule", "fallback cycle len is %d", #pages)
        return pages
    end

    local function generate_cycle()
        local debug_page = get_debug_page()

        if debug_page then
            cycle_pages = {debug_page}
        else
            cycle_pages = get_scheduled_pages()
        end

        if #cycle_pages == 0 then
            log("generate_cycle", "no scheduled pages. using fallback")
            cycle_pages = get_fallback_cycle()
        end

        log("generate_cycle", "generated cycle with %d pages", #cycle_pages)
    end

    local function get_prev()
        cycle_offset = cycle_offset - 1
        if cycle_offset < 1 then
            generate_cycle()
            cycle_offset = #cycle_pages
        end
        return cycle_pages[cycle_offset]
    end

    local function get_next()
        cycle_offset = cycle_offset + 1
        if cycle_offset > #cycle_pages then
            generate_cycle()
            cycle_offset = 1
        end
        return cycle_pages[cycle_offset]
    end

    return {
        get_prev = get_prev;
        get_next = get_next;
        find_by_key = find_by_key;
        find_by_gpio = find_by_gpio;
        find_by_remote = find_by_remote;
    }
end

local page_source = PageSource()
local job_queue = JobQueue()
local scheduler = Scheduler(page_source, job_queue)

local function init_streams(config)
    -- Initialize all configured streams
    for _, schedule in ipairs(config.schedules) do
        for _, page in ipairs(schedule.pages) do
            for _, tile in ipairs(page.tiles) do
                if tile.type == "stream" and tile.config.url then
                    -- Pre-initialize the stream
                    streams.get_stream(tile.config.url, tile.config.audio)
                end
            end
        end
    end
end

-- Add to your config update handler
util.json_watch("config.json", function(config)
    init_streams(config)  -- Initialize streams when config is loaded
    node.dispatch("config_updated", config)
    node.gc()
end)

-- Function to update a specific QR code instance's positioning settings
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

    -- Width/Height are determined by the QR code content and module size, not directly configurable here.
    -- We configure the *margin* and *position* type.
    if settings.width or settings.height then
        print("WARNING: QR width/height cannot be set directly via config. Size depends on content and global appearance settings (module_size).")
    end

    if settings.margin then
        instance.position_config.margin = settings.margin
        print("Instance " .. instance_id .. ": Updated margin to " .. settings.margin)
        config_updated = true
    end

    if settings.custom_x then
        instance.position_config.custom_x = settings.custom_x
        print("Instance " .. instance_id .. ": Updated custom_x to " .. settings.custom_x)
        config_updated = true
    end

    if settings.custom_y then
        instance.position_config.custom_y = settings.custom_y
        print("Instance " .. instance_id .. ": Updated custom_y to " .. settings.custom_y)
        config_updated = true
    end

    return config_updated
end

util.data_mapper{
    ["event/keyboard"] = function(raw_event)
        local event = json.decode(raw_event)
        dispatch_to_all_tiles("on_keyboard", event)
        return scheduler.handle_keyboard(event)
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
        -- The unified handle_remote_trigger now handles both QR and scheduler
        return scheduler.handle_remote_trigger(data)
    end,
    ["sys/cec/key"] = scheduler.handle_cec,
    ["plugin/(.*)/(.*)"] = function(tile_name, path, data)
        local impl = tile_loader.modules[tile_name]
        if impl and impl.data_trigger then
            impl.data_trigger(path, data)
        end
    end,
    -- Add handlers for updating QR code settings
    ["qr/position"] = function(data)
        local payload = json.decode(data)
        if type(payload) == "table" and payload.id and payload.settings then
            update_qr_position(payload.id, payload.settings)
        else
            print("ERROR: Invalid qr/position payload. Expected a table with id and settings fields")
        end
    end,
    ["qr/appearance"] = function(data)
        local settings = json.decode(data)
        local needs_regen = qrcode_overlay.update_appearance(settings)
        if needs_regen then
            print("QR appearance updated, triggering regeneration for visible instances.")
            -- Regenerate all visible QR codes as appearance affects all
            for id, instance in pairs(qr_code_instances) do
                if instance.is_visible and instance.trigger_data then
                    print("Regenerating QR instance: " .. id)
                    -- Use instance.trigger_data to regenerate the correct content
                    local new_draw_details = qrcode_overlay.handle_remote_trigger(instance.trigger_data, current_setup_id)
                    if new_draw_details then
                        instance.draw_details = new_draw_details
                        print("Successfully regenerated QR instance: " .. id)
                    else
                        print("ERROR: Failed to regenerate QR instance: " .. id)
                        instance.is_visible = false -- Hide if regeneration fails
                        instance.draw_details = nil
                    end
                end
            end
        else
            print("QR appearance updated, no regeneration needed.")
        end
    end,
}

-- Optional: Function to pre-generate QR codes for initially visible instances
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

-- Call initialization after everything is set up, perhaps before first render or after config loaded
-- For now, let's assume it's called after first config update where current_setup_id is known.
-- A better place might be at the very end of the script or after the first config_updated event.
-- To ensure current_setup_id is available, let's call it after the first config is processed.
local first_config_loaded = false
node.event("config_updated", function(config)
    -- ... (existing config_updated logic for layouts, background, current_setup_id) ...
    layouts = config.layouts
    for _, layout in ipairs(layouts) do
        for _, tile in ipairs(layout.tiles) do
            local asset = tile.asset
            if asset.type == "image" or asset.type == "video" then
                log("config_updated", "fixing layout asset %s", asset.asset_name)
                asset.asset_name = resource.open_file(asset.asset_name)
            end
        end
    end
    background = config.background
    
    if config.__metadata and config.__metadata.setup_id then
        current_setup_id = config.__metadata.setup_id
        log("config_updated", "Stored setup_id: %s", current_setup_id)
    else
        log("config_updated", "setup_id not found in config metadata")
        -- current_setup_id remains "UNKNOWN_SETUP" or its previous value
    end

    -- Initialize/Pre-generate QR codes after the first config (to ensure current_setup_id is set)
    if not first_config_loaded and current_setup_id ~= "UNKNOWN_SETUP" then
        initialize_qr_codes()
        first_config_loaded = true
    end

    -- ... (existing config_updated logic for scheduler reset) ...
    local setup_id = config.__metadata.setup_id
    local config_hash = config.__metadata.config_hash
    local reset_mode = config.reset_mode

    local force_reset

    if reset_mode == "config" then
        force_reset = config_hash ~= last_config_hash
    elseif reset_mode == "setup" then
        force_reset = setup_id ~= last_setup_id
    elseif reset_mode == "in_forever" then
        force_reset = scheduled_forever and config_hash ~= last_config_hash
    else -- "none"
        force_reset = false
    end

    if force_reset then
        print("config updated: forcing scheduler reset")
        reset_scheduler()
    end

    last_setup_id = setup_id
    last_config_hash = config_hash
end)

-- Override the render function to add QR code display
function node.render()
    streams.tick()
    FontCache.tick()
    ImageCache.tick()
    screen.setup()

    gl.clear(background.r, background.g, background.b, background.a)

    local now = sys.now()
    scheduler.tick(now)

    dispatch_to_all_tiles("each_frame")

    job_queue.tick(now)

    dispatch_to_all_tiles("overlay")

    -- === Draw QR Code Instances ===
    local now_for_qr = sys.now() -- Use consistent time for expiry checks
    local total_drawn_qr = 0

    for id, instance in pairs(qr_code_instances) do
        if instance.is_visible and instance.draw_details and instance.position_config then
            local pos_config = instance.position_config
            local dimensions = instance.draw_details.dimensions

            -- Use actual dimensions from draw_details for positioning calculation
            local qr_width = dimensions.total_width
            local qr_height = dimensions.total_height
            local margin = pos_config.margin or 20 -- Default margin if not set

            -- Calculate position based on selected corner or custom coordinates
            -- Note: The draw function expects the top-left corner (x, y) of the QR code *data* area,
            -- not including the border or title height.
            local qr_draw_x, qr_draw_y
            if pos_config.position == "top-left" then
                qr_draw_x = margin + dimensions.border_size
                qr_draw_y = margin + dimensions.title_height + dimensions.border_size
            elseif pos_config.position == "top-right" then
                qr_draw_x = NATIVE_WIDTH - qr_width - margin + dimensions.border_size
                qr_draw_y = margin + dimensions.title_height + dimensions.border_size
            elseif pos_config.position == "bottom-left" then
                qr_draw_x = margin + dimensions.border_size
                qr_draw_y = NATIVE_HEIGHT - qr_height - margin + dimensions.title_height + dimensions.border_size
            elseif pos_config.position == "bottom-right" then
                qr_draw_x = NATIVE_WIDTH - qr_width - margin + dimensions.border_size
                qr_draw_y = NATIVE_HEIGHT - qr_height - margin + dimensions.title_height + dimensions.border_size
            elseif pos_config.position == "custom" then
                -- For custom, assume provided (x,y) is the top-left of the *entire* QR area (including border/title)
                qr_draw_x = (pos_config.custom_x or 0) + dimensions.border_size
                qr_draw_y = (pos_config.custom_y or 0) + dimensions.title_height + dimensions.border_size
            else
                -- Default to bottom-right if invalid position
                qr_draw_x = NATIVE_WIDTH - qr_width - margin + dimensions.border_size
                qr_draw_y = NATIVE_HEIGHT - qr_height - margin + dimensions.title_height + dimensions.border_size
            end

            -- Try to draw the QR code instance
            local drawn = qrcode_overlay.draw_qr(instance.draw_details, qr_draw_x, qr_draw_y, now_for_qr)

            if drawn then
                total_drawn_qr = total_drawn_qr + 1
            else
                -- If drawing failed (e.g., expired), mark as not visible
                print("QR instance " .. id .. " failed to draw (likely expired). Hiding.")
                instance.is_visible = false
                instance.draw_details = nil -- Clear details
            end
        end
    end

    -- Draw debug marker last to ensure it's on top of all other content
    -- This ensures the marker doesn't get hidden by videos or other elements
    gl.pushMatrix()
        -- Use explicit Z coordinate to ensure it's drawn on top
        gl.translate(0, 0, 0.1)

        -- Draw white border first (slightly larger than the marker)
        colored:use{color = {1, 1, 1, 1}}  -- White color
        white_pixel:draw(8, 8, 32, 32)     -- White border
        colored:deactivate()

        -- Create blinking effect by varying alpha based on time
        local blink_alpha = math.abs(math.sin(now * 3)) * 0.5 + 0.5  -- Oscillates between 0.5 and 1.0
        colored:use{color = {1, 0, 0, blink_alpha}}  -- Red with changing alpha
        debug_marker:draw(10, 10, 30, 30)  -- Small red square in corner
        colored:deactivate()

        -- Removed: Green background rectangle drawing code
    gl.popMatrix()

    -- Print debugging info every few seconds
    local print_debug = (math.floor(now_for_qr) % 5 == 0)
    if print_debug and total_drawn_qr > 0 then
        print("\n==== QR CODE INSTANCE DEBUG INFO (" .. total_drawn_qr .. " visible) ====")
        for id, instance in pairs(qr_code_instances) do
            if instance.is_visible and instance.draw_details then
                local dims = instance.draw_details.dimensions
                local pos_cfg = instance.position_config
                print("  Instance ID:", id)
                print("    Position Cfg:", pos_cfg.position, "(Margin:", pos_cfg.margin, ")", "Custom:", pos_cfg.custom_x, ",", pos_cfg.custom_y)
                print("    Dimensions (Total):" .. dims.total_width .. "x" .. dims.total_height)
                print("    Permanent:", tostring(instance.draw_details.permanent_display), "Expiry:", instance.draw_details.expiry_time > 0 and math.floor(instance.draw_details.expiry_time - now_for_qr) or "N/A")
            end
        end
        print("============================================")
    elseif print_debug then
        print("[QR DEBUG] No QR instances visible.")
    end

    -- Old Debugging for reference:
    -- if drawn and qr_dimensions then
    --     print("DEBUG RENDER: QR matrix size:", qr_dimensions.matrix_size.width, "×", qr_dimensions.matrix_size.height, "modules")
    --     print("DEBUG RENDER: QR module size:", qr_dimensions.module_size, "pixels")
    --     print("DEBUG RENDER: QR pixel size:", qr_dimensions.pixel_size.width, "×", qr_dimensions.pixel_size.height, "pixels")
    --     print("DEBUG RENDER: QR total size:", qr_dimensions.total_size.width, "×", qr_dimensions.total_size.height, "pixels")
    --     print("DEBUG RENDER: QR border size:", qr_dimensions.border_size, "pixels")
    --     print("DEBUG RENDER: QR title height:", qr_dimensions.title_height, "pixels")
    --     
    --     -- Compare configured and actual sizes
    --     print("DEBUG RENDER: Size comparison - Configured:", qr_width, "×", qr_height, 
    --           "Actual:", qr_dimensions.pixel_size.width, "×", qr_dimensions.pixel_size.height)
    -- end
end