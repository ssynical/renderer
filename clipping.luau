--!strict
--!native
--!optimize 2

local Types = require("types")

type ClipRect = Types.ClipRect

local clipping = {}

local function create_clip_stack(): {ClipRect}
    return {}
end

local function push_clip_rect(stack: {ClipRect}, x: number, y: number, width: number, height: number)
    local new_clip: ClipRect = {
        x = x,
        y = y,
        width = width,
        height = height,
        active = true
    }
    
    if #stack > 0 then
        local current = stack[#stack]
        if current.active then
            local x1 = math.max(current.x, x)
            local y1 = math.max(current.y, y)
            local x2 = math.min(current.x + current.width, x + width)
            local y2 = math.min(current.y + current.height, y + height)
            
            if x2 > x1 and y2 > y1 then
                new_clip.x = x1
                new_clip.y = y1
                new_clip.width = x2 - x1
                new_clip.height = y2 - y1
            else
                new_clip.active = false
            end
        else
            new_clip.active = false
        end
    end
    
    table.insert(stack, new_clip)
end

local function pop_clip_rect(stack: {ClipRect})
    if #stack > 0 then
        table.remove(stack)
    end
end

local function is_point_clipped(stack: {ClipRect}, x: number, y: number): boolean
    if #stack == 0 then
        return false
    end
    
    local current = stack[#stack]
    if not current.active then
        return true
    end
    
    return x < current.x or x >= current.x + current.width or
           y < current.y or y >= current.y + current.height
end

local function clip_line(stack: {ClipRect}, x1: number, y1: number, x2: number, y2: number): (number?, number?, number?, number?)
    if #stack == 0 then
        return x1, y1, x2, y2
    end
    
    local current = stack[#stack]
    if not current.active then
        return nil
    end
    
    local left = current.x
    local right = current.x + current.width - 1
    local top = current.y
    local bottom = current.y + current.height - 1
    
    local function compute_outcode(x: number, y: number): number
        local code = 0
        if x < left then code = bit32.bor(code, 1) end
        if x > right then code = bit32.bor(code, 2) end
        if y < top then code = bit32.bor(code, 4) end
        if y > bottom then code = bit32.bor(code, 8) end
        return code
    end
    
    local outcode1 = compute_outcode(x1, y1)
    local outcode2 = compute_outcode(x2, y2)
    
    while true do
        if bit32.bor(outcode1, outcode2) == 0 then
            return x1, y1, x2, y2
        elseif bit32.band(outcode1, outcode2) ~= 0 then
            return nil
        else
            local x, y = 0, 0
            local outcode = outcode1 ~= 0 and outcode1 or outcode2
            
            if bit32.band(outcode, 8) ~= 0 then
                x = x1 + (x2 - x1) * (bottom - y1) / (y2 - y1)
                y = bottom
            elseif bit32.band(outcode, 4) ~= 0 then
                x = x1 + (x2 - x1) * (top - y1) / (y2 - y1)
                y = top
            elseif bit32.band(outcode, 2) ~= 0 then
                y = y1 + (y2 - y1) * (right - x1) / (x2 - x1)
                x = right
            elseif bit32.band(outcode, 1) ~= 0 then
                y = y1 + (y2 - y1) * (left - x1) / (x2 - x1)
                x = left
            end
            
            if outcode == outcode1 then
                x1 = x
                y1 = y
                outcode1 = compute_outcode(x1, y1)
            else
                x2 = x
                y2 = y
                outcode2 = compute_outcode(x2, y2)
            end
        end
    end
end

local function clip_rect(stack: {ClipRect}, x: number, y: number, width: number, height: number): (number?, number?, number?, number?)
    if #stack == 0 then
        return x, y, width, height
    end
    
    local current = stack[#stack]
    if not current.active then
        return nil
    end
    
    local x1 = math.max(current.x, x)
    local y1 = math.max(current.y, y)
    local x2 = math.min(current.x + current.width, x + width)
    local y2 = math.min(current.y + current.height, y + height)
    
    if x2 > x1 and y2 > y1 then
        return x1, y1, x2 - x1, y2 - y1
    end
    
    return nil
end

local function get_current_clip_bounds(stack: {ClipRect}): (number?, number?, number?, number?)
    if #stack == 0 then
        return nil
    end
    
    local current = stack[#stack]
    if not current.active then
        return nil
    end
    
    return current.x, current.y, current.width, current.height
end

clipping.create_clip_stack = create_clip_stack
clipping.push_clip_rect = push_clip_rect
clipping.pop_clip_rect = pop_clip_rect
clipping.is_point_clipped = is_point_clipped
clipping.clip_line = clip_line
clipping.clip_rect = clip_rect
clipping.get_current_clip_bounds = get_current_clip_bounds

return clipping