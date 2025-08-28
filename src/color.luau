--!strict
--!native
--!optimize 2

local Types = require("types")

type Color = Types.Color
type GradientStop = Types.GradientStop

local colorlib = {}

local function clamp(v: number): number
    return math.max(0, math.min(255, math.floor(v)))
end

local function rgb(r: number, g: number, b: number): Color
    return bit32.bor(
        bit32.band(clamp(r), 0xFF),
        bit32.lshift(bit32.band(clamp(g), 0xFF), 8),
        bit32.lshift(bit32.band(clamp(b), 0xFF), 16)
    )
end

local function rgba(r: number, g: number, b: number, a: number): Color
    return bit32.bor(
        bit32.band(clamp(r), 0xFF),
        bit32.lshift(bit32.band(clamp(g), 0xFF), 8),
        bit32.lshift(bit32.band(clamp(b), 0xFF), 16),
        bit32.lshift(bit32.band(clamp(a * 255), 0xFF), 24)
    )
end

local function extract_rgba(color: Color): (number, number, number, number)
    local r = bit32.band(color, 0xFF)
    local g = bit32.band(bit32.rshift(color, 8), 0xFF)
    local b = bit32.band(bit32.rshift(color, 16), 0xFF)
    local a = bit32.band(bit32.rshift(color, 24), 0xFF)
    return r, g, b, a / 255
end

local function blend_colors(bg: Color, fg: Color, alpha: number): Color
    alpha = math.max(0, math.min(1, alpha))
    
    local bg_r = bit32.band(bg, 0xFF)
    local bg_g = bit32.band(bit32.rshift(bg, 8), 0xFF)
    local bg_b = bit32.band(bit32.rshift(bg, 16), 0xFF)
    
    local fg_r = bit32.band(fg, 0xFF)
    local fg_g = bit32.band(bit32.rshift(fg, 8), 0xFF)
    local fg_b = bit32.band(bit32.rshift(fg, 16), 0xFF)
    
    local r = math.floor(bg_r * (1 - alpha) + fg_r * alpha)
    local g = math.floor(bg_g * (1 - alpha) + fg_g * alpha)
    local b = math.floor(bg_b * (1 - alpha) + fg_b * alpha)
    
    return rgb(r, g, b)
end

local function blend_multiply(bg: Color, fg: Color): Color
    local bg_r, bg_g, bg_b = extract_rgba(bg)
    local fg_r, fg_g, fg_b = extract_rgba(fg)
    
    return rgb(
        (bg_r * fg_r) / 255,
        (bg_g * fg_g) / 255,
        (bg_b * fg_b) / 255
    )
end

local function blend_screen(bg: Color, fg: Color): Color
    local bg_r, bg_g, bg_b = extract_rgba(bg)
    local fg_r, fg_g, fg_b = extract_rgba(fg)
    
    return rgb(
        255 - ((255 - bg_r) * (255 - fg_r)) / 255,
        255 - ((255 - bg_g) * (255 - fg_g)) / 255,
        255 - ((255 - bg_b) * (255 - fg_b)) / 255
    )
end

local function blend_overlay(bg: Color, fg: Color): Color
    local bg_r, bg_g, bg_b = extract_rgba(bg)
    local fg_r, fg_g, fg_b = extract_rgba(fg)
    
    local function overlay_channel(base: number, blend: number): number
        if base < 128 then
            return (2 * base * blend) / 255
        else
            return 255 - (2 * (255 - base) * (255 - blend)) / 255
        end
    end
    
    return rgb(
        overlay_channel(bg_r, fg_r),
        overlay_channel(bg_g, fg_g),
        overlay_channel(bg_b, fg_b)
    )
end

local function interpolate_color(color1: Color, color2: Color, t: number): Color
    t = math.max(0, math.min(1, t))
    
    local r1, g1, b1 = extract_rgba(color1)
    local r2, g2, b2 = extract_rgba(color2)
    
    return rgb(
        r1 + (r2 - r1) * t,
        g1 + (g2 - g1) * t,
        b1 + (b2 - b1) * t
    )
end

local function sample_gradient(stops: {GradientStop}, t: number): Color
    if #stops == 0 then
        return 0x000000
    end
    
    if #stops == 1 then
        return stops[1].color
    end
    
    t = math.max(0, math.min(1, t))
    
    for i = 1, #stops - 1 do
        local stop1 = stops[i]
        local stop2 = stops[i + 1]
        
        if t >= stop1.position and t <= stop2.position then
            local segment_t = (t - stop1.position) / (stop2.position - stop1.position)
            return interpolate_color(stop1.color, stop2.color, segment_t)
        end
    end
    
    return stops[#stops].color
end

local function hsv_to_rgb(h: number, s: number, v: number): Color
    h = h % 360
    s = math.max(0, math.min(1, s))
    v = math.max(0, math.min(1, v))
    
    local c = v * s
    local x = c * (1 - math.abs((h / 60) % 2 - 1))
    local m = v - c
    
    local r, g, b = 0, 0, 0
    
    if h < 60 then
        r, g, b = c, x, 0
    elseif h < 120 then
        r, g, b = x, c, 0
    elseif h < 180 then
        r, g, b = 0, c, x
    elseif h < 240 then
        r, g, b = 0, x, c
    elseif h < 300 then
        r, g, b = x, 0, c
    else
        r, g, b = c, 0, x
    end
    
    return rgb((r + m) * 255, (g + m) * 255, (b + m) * 255)
end

colorlib.rgb = rgb
colorlib.rgba = rgba
colorlib.extract_rgba = extract_rgba
colorlib.blend_colors = blend_colors
colorlib.blend_multiply = blend_multiply
colorlib.blend_screen = blend_screen
colorlib.blend_overlay = blend_overlay
colorlib.interpolate_color = interpolate_color
colorlib.sample_gradient = sample_gradient
colorlib.hsv_to_rgb = hsv_to_rgb
colorlib.clamp = clamp

colorlib.Black = 0x000000
colorlib.White = 0xFFFFFF
colorlib.Red = 0x0000FF
colorlib.Green = 0x00FF00
colorlib.Blue = 0xFF0000
colorlib.Gray = 0x808080
colorlib.Yellow = 0x00FFFF
colorlib.Cyan = 0xFFFF00
colorlib.Magenta = 0xFF00FF
colorlib.Orange = 0x00A6FF
colorlib.Purple = 0x800080
colorlib.Transparent = 0x000000

return colorlib