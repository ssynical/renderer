--!strict
--!native
--!optimize 2

local Types = require("types")

type Rect = Types.Rect
type SpatialNode = Types.SpatialNode

local spatial = {}

local MAX_DEPTH = 5
local MAX_OBJECTS = 10

local function rect_contains_point(rect: Rect, x: number, y: number): boolean
    return x >= rect.x and x < rect.x + rect.width and 
           y >= rect.y and y < rect.y + rect.height
end

local function rect_intersects_rect(rect1: Rect, rect2: Rect): boolean
    return rect1.x < rect2.x + rect2.width and
           rect1.x + rect1.width > rect2.x and
           rect1.y < rect2.y + rect2.height and
           rect1.y + rect1.height > rect2.y
end

local function create_node(bounds: Rect, depth: number): SpatialNode
    return {
        bounds = bounds,
        items = {},
        children = nil,
        depth = depth
    }
end

local function subdivide(node: SpatialNode)
    if node.children then
        return
    end
    
    local half_width = node.bounds.width / 2
    local half_height = node.bounds.height / 2
    local x = node.bounds.x
    local y = node.bounds.y
    
    node.children = {
        create_node({x = x, y = y, width = half_width, height = half_height}, node.depth + 1),
        create_node({x = x + half_width, y = y, width = half_width, height = half_height}, node.depth + 1),
        create_node({x = x, y = y + half_height, width = half_width, height = half_height}, node.depth + 1),
        create_node({x = x + half_width, y = y + half_height, width = half_width, height = half_height}, node.depth + 1)
    }
end

local function get_index(node: SpatialNode, rect: Rect): number
    if not node.children then
        return -1
    end
    
    local vertical_midpoint = node.bounds.x + node.bounds.width / 2
    local horizontal_midpoint = node.bounds.y + node.bounds.height / 2
    
    local top_quadrant = rect.y < horizontal_midpoint and rect.y + rect.height < horizontal_midpoint
    local bottom_quadrant = rect.y > horizontal_midpoint
    local left_quadrant = rect.x < vertical_midpoint and rect.x + rect.width < vertical_midpoint
    local right_quadrant = rect.x > vertical_midpoint
    
    if left_quadrant then
        if top_quadrant then
            return 1
        elseif bottom_quadrant then
            return 3
        end
    elseif right_quadrant then
        if top_quadrant then
            return 2
        elseif bottom_quadrant then
            return 4
        end
    end
    
    return -1
end

local function insert_item(node: SpatialNode, item: any, rect: Rect)
    if node.children then
        local index = get_index(node, rect)
        if index ~= -1 then
            insert_item(node.children[index], item, rect)
            return
        end
    end
    
    table.insert(node.items, {item = item, rect = rect})
    
    if #node.items > MAX_OBJECTS and node.depth < MAX_DEPTH then
        if not node.children then
            subdivide(node)
        end
        
        local i = 1
        while i <= #node.items do
            local obj = node.items[i]
            local index = get_index(node, obj.rect)
            if index ~= -1 then
                insert_item(node.children[index], obj.item, obj.rect)
                table.remove(node.items, i)
            else
                i = i + 1
            end
        end
    end
end

local function retrieve_items(node: SpatialNode, rect: Rect, result: {any})
    local index = get_index(node, rect)
    if index ~= -1 and node.children then
        retrieve_items(node.children[index], rect, result)
    end
    
    for _, obj in ipairs(node.items) do
        if rect_intersects_rect(obj.rect, rect) then
            table.insert(result, obj.item)
        end
    end
    
    if node.children then
        for _, child in ipairs(node.children) do
            if rect_intersects_rect(child.bounds, rect) then
                retrieve_items(child, rect, result)
            end
        end
    end
end

local function clear_node(node: SpatialNode)
    for i = #node.items, 1, -1 do
        node.items[i] = nil
    end
    
    if node.children then
        for _, child in ipairs(node.children) do
            clear_node(child)
        end
        node.children = nil
    end
end

local function create_quadtree(width: number, height: number): SpatialNode
    return create_node({x = 0, y = 0, width = width, height = height}, 0)
end

spatial.create_quadtree = create_quadtree
spatial.insert_item = insert_item
spatial.retrieve_items = retrieve_items
spatial.clear_node = clear_node
spatial.rect_contains_point = rect_contains_point
spatial.rect_intersects_rect = rect_intersects_rect

return spatial