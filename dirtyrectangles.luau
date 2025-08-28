--!strict
--!native
--!optimize 2

local Types = require("types")

type DirtyRect = Types.DirtyRect

local DirtyRectangles = {}

local function create_dirty_system(width: number, height: number): {DirtyRect}
    return {
        {x1 = 0, y1 = 0, x2 = width, y2 = height, marked = false}
    }
end

local function mark_dirty(dirty_rects: {DirtyRect}, x: number, y: number, width: number, height: number)
    local new_rect: DirtyRect = {
        x1 = math.max(0, math.floor(x)),
        y1 = math.max(0, math.floor(y)),
        x2 = math.floor(x + width),
        y2 = math.floor(y + height),
        marked = true
    }
    
    if new_rect.x2 <= new_rect.x1 or new_rect.y2 <= new_rect.y1 then
        return
    end
    
    table.insert(dirty_rects, new_rect)
end

local function merge_overlapping_rects(dirty_rects: {DirtyRect}): {DirtyRect}
    local merged = {}
    local used = {}
    
    for i, rect1 in ipairs(dirty_rects) do
        if not used[i] and rect1.marked then
            local merged_rect = {
                x1 = rect1.x1,
                y1 = rect1.y1,
                x2 = rect1.x2,
                y2 = rect1.y2,
                marked = true
            }
            
            used[i] = true
            local changed = true
            
            while changed do
                changed = false
                for j, rect2 in ipairs(dirty_rects) do
                    if not used[j] and rect2.marked then
                        if not (merged_rect.x2 < rect2.x1 or merged_rect.x1 > rect2.x2 or
                                merged_rect.y2 < rect2.y1 or merged_rect.y1 > rect2.y2) then
                            merged_rect.x1 = math.min(merged_rect.x1, rect2.x1)
                            merged_rect.y1 = math.min(merged_rect.y1, rect2.y1)
                            merged_rect.x2 = math.max(merged_rect.x2, rect2.x2)
                            merged_rect.y2 = math.max(merged_rect.y2, rect2.y2)
                            used[j] = true
                            changed = true
                        end
                    end
                end
            end
            
            table.insert(merged, merged_rect)
        end
    end
    
    return merged
end

local function optimize_dirty_rects(dirty_rects: {DirtyRect}, max_rects: number): {DirtyRect}
    if #dirty_rects <= max_rects then
        return dirty_rects
    end
    
    local merged = merge_overlapping_rects(dirty_rects)
    
    if #merged <= max_rects then
        return merged
    end
    
    table.sort(merged, function(a, b)
        local area_a = (a.x2 - a.x1) * (a.y2 - a.y1)
        local area_b = (b.x2 - b.x1) * (b.y2 - b.y1)
        return area_a > area_b
    end)
    
    local result = {}
    for i = 1, math.min(max_rects, #merged) do
        table.insert(result, merged[i])
    end
    
    return result
end

local function is_point_in_dirty_rects(dirty_rects: {DirtyRect}, x: number, y: number): boolean
    for _, rect in ipairs(dirty_rects) do
        if rect.marked and x >= rect.x1 and x < rect.x2 and y >= rect.y1 and y < rect.y2 then
            return true
        end
    end
    return false
end

local function clear_dirty_rects(dirty_rects: {DirtyRect})
    for i = #dirty_rects, 1, -1 do
        if dirty_rects[i].marked then
            table.remove(dirty_rects, i)
        end
    end
end

local function get_dirty_bounds(dirty_rects: {DirtyRect}): (number, number, number, number)
    local min_x, min_y = math.huge, math.huge
    local max_x, max_y = -math.huge, -math.huge
    local has_dirty = false
    
    for _, rect in ipairs(dirty_rects) do
        if rect.marked then
            min_x = math.min(min_x, rect.x1)
            min_y = math.min(min_y, rect.y1)
            max_x = math.max(max_x, rect.x2)
            max_y = math.max(max_y, rect.y2)
            has_dirty = true
        end
    end
    
    if not has_dirty then
        return 0, 0, 0, 0
    end
    
    return min_x, min_y, max_x - min_x, max_y - min_y
end

DirtyRectangles.create_dirty_system = create_dirty_system
DirtyRectangles.mark_dirty = mark_dirty
DirtyRectangles.merge_overlapping_rects = merge_overlapping_rects
DirtyRectangles.optimize_dirty_rects = optimize_dirty_rects
DirtyRectangles.is_point_in_dirty_rects = is_point_in_dirty_rects
DirtyRectangles.clear_dirty_rects = clear_dirty_rects
DirtyRectangles.get_dirty_bounds = get_dirty_bounds

return DirtyRectangles