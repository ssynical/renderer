--!strict
--!native
--!optimize 2

local Types = require("types")
local ColorUtils = require("color")

type Color = Types.Color
type Point = Types.Point
type LinearGradient = Types.LinearGradient
type RadialGradient = Types.RadialGradient

local shapes = {}

-- Helper function to interpolate between two colors
local function lerp_color(color1: Color, color2: Color, t: number): Color
    local r1 = bit32.band(color1, 0xFF)
    local g1 = bit32.band(bit32.rshift(color1, 8), 0xFF)
    local b1 = bit32.band(bit32.rshift(color1, 16), 0xFF)
    local a1 = bit32.band(bit32.rshift(color1, 24), 0xFF)
    
    local r2 = bit32.band(color2, 0xFF)
    local g2 = bit32.band(bit32.rshift(color2, 8), 0xFF)
    local b2 = bit32.band(bit32.rshift(color2, 16), 0xFF)
    local a2 = bit32.band(bit32.rshift(color2, 24), 0xFF)
    
    local r = math.floor(r1 + (r2 - r1) * t)
    local g = math.floor(g1 + (g2 - g1) * t)
    local b = math.floor(b1 + (b2 - b1) * t)
    local a = math.floor(a1 + (a2 - a1) * t)
    
    return bit32.bor(r, bit32.lshift(g, 8), bit32.lshift(b, 16), bit32.lshift(a, 24))
end

-- Sample color from linear gradient at given position
local function sample_linear_gradient(gradient: LinearGradient, x: number, y: number): Color
    local dx = gradient.x2 - gradient.x1
    local dy = gradient.y2 - gradient.y1
    local length_sq = dx * dx + dy * dy
    
    if length_sq == 0 then
        return gradient.stops[1].color
    end
    
    local px = x - gradient.x1
    local py = y - gradient.y1
    local dot_product = px * dx + py * dy
    local t = math.max(0, math.min(1, dot_product / length_sq))
    
    -- Find the appropriate color stops
    for i = 1, #gradient.stops - 1 do
        local stop1 = gradient.stops[i]
        local stop2 = gradient.stops[i + 1]
        
        if t >= stop1.position and t <= stop2.position then
            local local_t = (t - stop1.position) / (stop2.position - stop1.position)
            return lerp_color(stop1.color, stop2.color, local_t)
        end
    end
    
    -- Fallback to first or last color
    if t <= gradient.stops[1].position then
        return gradient.stops[1].color
    else
        return gradient.stops[#gradient.stops].color
    end
end

-- Sample color from radial gradient at given position
local function sample_radial_gradient(gradient: RadialGradient, x: number, y: number): Color
    local dx = x - gradient.cx
    local dy = y - gradient.cy
    local distance = math.sqrt(dx * dx + dy * dy)
    local t = math.max(0, math.min(1, distance / gradient.r))
    
    -- Find the appropriate color stops
    for i = 1, #gradient.stops - 1 do
        local stop1 = gradient.stops[i]
        local stop2 = gradient.stops[i + 1]
        
        if t >= stop1.position and t <= stop2.position then
            local local_t = (t - stop1.position) / (stop2.position - stop1.position)
            return lerp_color(stop1.color, stop2.color, local_t)
        end
    end
    
    -- Fallback to first or last color
    if t <= gradient.stops[1].position then
        return gradient.stops[1].color
    else
        return gradient.stops[#gradient.stops].color
    end
end

function shapes.draw_rect(draw_pixel: (number, number, Color, number?) -> (), 
                                   x: number, y: number, w: number, h: number, 
                                   color: Color, filled: boolean, alpha: number?)
    if filled then
        for py = y, y + h - 1 do
            for px = x, x + w - 1 do
                draw_pixel(px, py, color, alpha)
            end
        end
    else
        -- Top and bottom edges
        for px = x, x + w - 1 do
            draw_pixel(px, y, color, alpha)
            draw_pixel(px, y + h - 1, color, alpha)
        end
        -- Left and right edges
        for py = y + 1, y + h - 2 do
            draw_pixel(x, py, color, alpha)
            draw_pixel(x + w - 1, py, color, alpha)
        end
    end
end

function shapes.draw_rounded_rect(draw_pixel: (number, number, Color, number?) -> (), 
                                          x: number, y: number, w: number, h: number, radius: number,
                                          color: Color, filled: boolean, alpha: number?)
    radius = math.min(radius, math.min(w, h) / 2)
    
    if filled then
        -- Fill the main rectangle areas
        shapes.draw_rect(draw_pixel, x + radius, y, w - 2 * radius, h, color, true, alpha)
        shapes.draw_rect(draw_pixel, x, y + radius, radius, h - 2 * radius, color, true, alpha)
        shapes.draw_rect(draw_pixel, x + w - radius, y + radius, radius, h - 2 * radius, color, true, alpha)
        
        -- Draw rounded corners
        local corners = {
            {x + radius, y + radius},           -- top-left
            {x + w - radius - 1, y + radius},   -- top-right
            {x + radius, y + h - radius - 1},   -- bottom-left
            {x + w - radius - 1, y + h - radius - 1} -- bottom-right
        }
        
        for _, corner in ipairs(corners) do
            for dy = -radius, radius do
                for dx = -radius, radius do
                    if dx * dx + dy * dy <= radius * radius then
                        draw_pixel(corner[1] + dx, corner[2] + dy, color, alpha)
                    end
                end
            end
        end
    else
        -- Draw the outline (simplified version)
        shapes.draw_rect(draw_pixel, x, y, w, h, color, false, alpha)
    end
end

function shapes.draw_ellipse(draw_pixel: (number, number, Color, number?) -> (), 
                                     cx: number, cy: number, rx: number, ry: number, 
                                     color: Color, filled: boolean, alpha: number?)
    if filled then
        for y = math.floor(cy - ry), math.ceil(cy + ry) do
            local dy = y - cy
            local dx_max = rx * math.sqrt(math.max(0, 1 - (dy * dy) / (ry * ry)))
            
            for x = math.floor(cx - dx_max), math.ceil(cx + dx_max) do
                local dx = x - cx
                if (dx * dx) / (rx * rx) + (dy * dy) / (ry * ry) <= 1 then
                    draw_pixel(x, y, color, alpha)
                end
            end
        end
    else
        -- Bresenham-like ellipse algorithm for outline
        local x, y = 0, ry
        local rx_sq = rx * rx
        local ry_sq = ry * ry
        local two_rx_sq = 2 * rx_sq
        local two_ry_sq = 2 * ry_sq
        local p = ry_sq - rx_sq * ry + 0.25 * rx_sq
        
        local function draw_ellipse_points(cx: number, cy: number, x: number, y: number)
            draw_pixel(cx + x, cy + y, color, alpha)
            draw_pixel(cx - x, cy + y, color, alpha)
            draw_pixel(cx + x, cy - y, color, alpha)
            draw_pixel(cx - x, cy - y, color, alpha)
        end
        
        -- Region 1
        while two_ry_sq * x < two_rx_sq * y do
            draw_ellipse_points(cx, cy, x, y)
            x = x + 1
            if p < 0 then
                p = p + two_ry_sq * x + ry_sq
            else
                y = y - 1
                p = p + two_ry_sq * x - two_rx_sq * y + ry_sq
            end
        end
        
        -- Region 2
        p = ry_sq * (x + 0.5) * (x + 0.5) + rx_sq * (y - 1) * (y - 1) - rx_sq * ry_sq
        while y >= 0 do
            draw_ellipse_points(cx, cy, x, y)
            y = y - 1
            if p > 0 then
                p = p - two_rx_sq * y + rx_sq
            else
                x = x + 1
                p = p + two_ry_sq * x - two_rx_sq * y + rx_sq
            end
        end
    end
end

function shapes.draw_bezier_curve(draw_pixel: (number, number, Color, number?) -> (), 
                                          p0: Point, p1: Point, p2: Point, p3: Point, 
                                          color: Color, segments: number?, alpha: number?)
    segments = segments or 50
    
    for i = 0, segments do
        local t = i / segments
        local t2 = t * t
        local t3 = t2 * t
        local mt = 1 - t
        local mt2 = mt * mt
        local mt3 = mt2 * mt
        
        local x = mt3 * p0[1] + 3 * mt2 * t * p1[1] + 3 * mt * t2 * p2[1] + t3 * p3[1]
        local y = mt3 * p0[2] + 3 * mt2 * t * p1[2] + 3 * mt * t2 * p2[2] + t3 * p3[2]
        
        draw_pixel(math.floor(x), math.floor(y), color, alpha)
    end
end

function shapes.draw_arc(draw_pixel: (number, number, Color, number?) -> (), 
                                 cx: number, cy: number, radius: number, 
                                 start_angle: number, end_angle: number, 
                                 color: Color, alpha: number?)
    local segments = math.max(8, math.floor(radius * (end_angle - start_angle) / (2 * math.pi) * 32))
    
    for i = 0, segments do
        local t = i / segments
        local angle = start_angle + t * (end_angle - start_angle)
        local x = cx + math.cos(angle) * radius
        local y = cy + math.sin(angle) * radius
        draw_pixel(math.floor(x), math.floor(y), color, alpha)
    end
end

function shapes.draw_linear_gradient(draw_pixel: (number, number, Color, number?) -> (), 
                                            x: number, y: number, w: number, h: number, 
                                            gradient: LinearGradient, alpha: number?)
    for py = y, y + h - 1 do
        for px = x, x + w - 1 do
            local gradient_color = sample_linear_gradient(gradient, px, py)
            draw_pixel(px, py, gradient_color, alpha)
        end
    end
end

function shapes.draw_radial_gradient(draw_pixel: (number, number, Color, number?) -> (), 
                                            x: number, y: number, w: number, h: number, 
                                            gradient: RadialGradient, alpha: number?)
    for py = y, y + h - 1 do
        for px = x, x + w - 1 do
            local gradient_color = sample_radial_gradient(gradient, px, py)
            draw_pixel(px, py, gradient_color, alpha)
        end
    end
end

function shapes.flood_fill(draw_pixel: (number, number, Color, number?) -> (), 
                                  get_pixel: (number, number) -> Color,
                                  x: number, y: number, new_color: Color, 
                                  width: number, height: number, alpha: number?)
    x, y = math.floor(x), math.floor(y)
    if x < 0 or x >= width or y < 0 or y >= height then
        return
    end
    
    local target_color = get_pixel(x, y)
    if target_color == new_color then
        return
    end
    
    local stack = {{x, y}}
    local visited = {}
    
    while #stack > 0 do
        local current = table.remove(stack)
        local cx, cy = current[1], current[2]
        
        if cx < 0 or cx >= width or cy < 0 or cy >= height then
            continue
        end
        
        local key = cy * width + cx
        if visited[key] then
            continue
        end
        
        if get_pixel(cx, cy) ~= target_color then
            continue
        end
        
        visited[key] = true
        draw_pixel(cx, cy, new_color, alpha)
        
        table.insert(stack, {cx + 1, cy})
        table.insert(stack, {cx - 1, cy})
        table.insert(stack, {cx, cy + 1})
        table.insert(stack, {cx, cy - 1})
    end
end

return shapes