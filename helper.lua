local M = {}

local easing = require "easing"

local min, max, abs, floor = math.min, math.max, math.abs, math.floor

function M.in_epsilon(a, b, e)
    return abs(a - b) <= e
end

function M.ramp(t_s, t_e, t_c, ramp_time)
    if ramp_time == 0 then return 1 end
    local delta_s = t_c - t_s
    local delta_e = t_e - t_c
    return min(1, delta_s * 1/ramp_time, delta_e * 1/ramp_time)
end

function M.wait_frame()
    return coroutine.yield(true)
end

function M.wait_t(t)
    local now = sys.now()
    if now >= t then
        return now
    end
    while true do
        local now = M.wait_frame()
        if now >= t then
            return now
        end
    end
end

function M.frame_between(starts, ends)
    return function()
        local now
        while true do
            now = M.wait_frame()
            if now >= starts then
                break
            end
        end
        if now < ends then
            return now
        end
    end
end


function M.mktween(fn)
    return function(sx1, sy1, sx2, sy2, ex1, ey1, ex2, ey2, progress)
        return fn(progress, sx1, ex1-sx1, 1),
               fn(progress, sy1, ey1-sy1, 1),
               fn(progress, sx2, ex2-sx2, 1),
               fn(progress, sy2, ey2-sy2, 1)
    end
end

M.movements = {
    linear = M.mktween(easing.linear),
    smooth = M.mktween(easing.inOutQuint),
}

function M.trim(s)
    return s:match "^%s*(.-)%s*$"
end

function M.split(str, delim)
    local result, pat, last = {}, "(.-)" .. delim .. "()", 1
    for part, pos in string.gmatch(str, pat) do
        result[#result+1] = part
        last = pos
    end
    result[#result+1] = string.sub(str, last)
    return result
end

function M.wrap(str, limit, indent, indent1)
    limit = limit or 72
    local here = 1
    local wrapped = str:gsub("(%s+)()(%S+)()", function(sp, st, word, fi)
        if fi-here > limit then
            here = st
            return "\n"..word
        end
    end)
    local splitted = {}
    for token in string.gmatch(wrapped, "[^\n]+") do
        splitted[#splitted + 1] = token 
    end
    return splitted
end 

function M.parse_rgb(hex)
    hex = hex:gsub("#","")
    return tonumber("0x"..hex:sub(1,2))/255, tonumber("0x"..hex:sub(3,4))/255, tonumber("0x"..hex:sub(5,6))/255
end

function M.draw_system_info_page(system_info, NATIVE_WIDTH, NATIVE_HEIGHT)
    if not system_info then
        local f = resource.load_font("default-font.ttf")
        local msg = "No system information available"
        local w = f:width(msg, 40)
        f:write((NATIVE_WIDTH - w) / 2, NATIVE_HEIGHT / 2, msg, 40, 1, 1, 1, 1)
        return
    end
    local f = resource.load_font("default-font.ttf")
    local fs, lh, m, ts = 32, 45, 40, 48
    resource.create_colored_texture(0, 0, 0, 0.95):draw(0, 0, NATIVE_WIDTH, NATIVE_HEIGHT)
    f:write(m, m, "System Information", ts, 0.2, 0.8, 1, 1)
    local y, x1, x2, lw = m + ts + 40, m, m + (NATIVE_WIDTH - m * 2) / 2 + 20, 350
    local function fmt_val(k, v)
        if type(v) ~= "number" then return tostring(v) end
        if k:match("temperature") or k:match("cpu") then return string.format("%.1f", v) end
        if k:match("disk") or k:match("network") or k:match("uptime") or k:match("boot") then
            if v > 1073741824 then return string.format("%.2f GB", v / 1073741824) end
            if v > 1048576 then return string.format("%.2f MB", v / 1048576) end
            if v > 1024 then return string.format("%.2f KB", v / 1024) end
        end
        return tostring(v)
    end
    local function fmt_key(k)
        return k:gsub("_", " "):gsub("(%a)([%w_']*)", function(a, b) return a:upper() .. b:lower() end)
    end
    local items = {}
    for k, v in pairs(system_info) do table.insert(items, {k = fmt_key(k), v = fmt_val(k, v)}) end
    table.sort(items, function(a, b) return a.k < b.k end)
    for i, item in ipairs(items) do
        if y + lh > NATIVE_HEIGHT - m - 60 then break end
        local col = (i - 1) % 2
        local x = col == 0 and x1 or x2
        if col == 0 and i > 1 then y = y + lh end
        f:write(x, y, item.k .. ":", fs, 0.7, 0.7, 0.7, 1)
        f:write(x + lw, y, item.v, fs, 1, 1, 1, 1)
    end
    f:write(m, NATIVE_HEIGHT - m - 24, "API: /device_info/pagce_info/page/off to exit", 24, 0.5, 0.5, 0.5, 1)
end

return M
