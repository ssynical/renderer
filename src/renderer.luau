--!strict
--!native
--!optimize 2

--[[>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
||                                                                              ||
||                  <// runluau renderer engine //>                             ||
||                                                                              ||
||            coded with real hands by me, with love                            ||
||            alive since 06.12.2024 | last big update: 28.8.2025               ||
||                                                                              ||
>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>]]--

local Types = require("types")
local colorlib = require("color")
local MemoryPools = require("memorypools")
local spatial = require("spatial")
local DirtyRectangles = require("dirtyrectangles")
local shapes = require("shapes")
local BatchRenderer = require("batch")
local ClippingSystem = require("clipping")

type Color = Types.Color
type Point = Types.Point
type Polygon = Types.Polygon
type RendererOptions = Types.RendererOptions
type DebugInfo = Types.DebugInfo
type WindowBuffer = Types.WindowBuffer
type LinearGradient = Types.LinearGradient
type RadialGradient = Types.RadialGradient

local Renderer = {}

local set_global_debug_mode = false

local function create(width: number, height: number, title: string?, options: RendererOptions?)
    if type(width) ~= "number" or width <= 0 then
        error("Width must be a positive number")
    end
    if type(height) ~= "number" or height <= 0 then
        error("Height must be a positive number")
    end
    
    options = options or {}
    local optionsuntyped: any = options or {}

    local pixel_size = optionsuntyped.pixel_size or 1
    local debug_mode = optionsuntyped.debug_mode or set_global_debug_mode
    local enable_dirty_rects = optionsuntyped.enable_dirty_rects or true
    local max_batch_size = optionsuntyped.max_batch_size or 1000
    
    local debug_info: DebugInfo = {
        draw_calls = 0,
        pixels_drawn = 0,
        batched_calls = 0,
        dirty_rects_active = 0,
        start_time = os.clock(),
        memory_pools = {}
    }
    
    local framebuffer = gfx.create_window(width, height, title, pixel_size) :: WindowBuffer
    if not framebuffer then
        error("Failed to create window buffer")
    end
    
    local dirty_rects = enable_dirty_rects and DirtyRectangles.create_dirty_system(width, height) or nil
    local batch_system = BatchRenderer.create_batch_system(max_batch_size)
    local spatial_tree = spatial.create_quadtree(width, height)
    local clip_stack = ClippingSystem.create_clip_stack()
    local back_buffer = buffer.create(width * height * 4)
    
    local function safe_buffer_bounds(x: number, y: number, w: number, h: number): (number, number, number, number, boolean)
        x = math.max(0, math.min(width - 1, math.floor(x)))
        y = math.max(0, math.min(height - 1, math.floor(y)))
        w = math.max(0, math.min(width - x, math.floor(w)))
        h = math.max(0, math.min(height - y, math.floor(h)))
        
        local valid = w > 0 and h > 0 and x + w <= width and y + h <= height
        return x, y, w, h, valid
    end
    
    local function get_pixel(x: number, y: number): Color
        x, y = math.floor(x), math.floor(y)
        if x < 0 or x >= width or y < 0 or y >= height then
            return 0
        end
        return buffer.readu32(back_buffer, (y * width + x) * 4)
    end

    local function draw_pixel(x: number, y: number, color: Color, alpha: number?): boolean
        x, y = math.floor(x), math.floor(y)
        if x < 0 or x >= width or y < 0 or y >= height then
            return false
        end
        
        if ClippingSystem.is_point_clipped(clip_stack, x, y) then
            return false
        end
        
        local offset = (y * width + x) * 4
        
        if alpha and alpha < 1 then
            local existing_color = buffer.readu32(back_buffer, offset)
            color = colorlib.blend_colors(existing_color, color, alpha)
        end
        
        buffer.writeu32(back_buffer, offset, color)
        
        if dirty_rects then
            DirtyRectangles.mark_dirty(dirty_rects, x, y, 1, 1)
        end
        
        if debug_mode then
            debug_info.pixels_drawn = debug_info.pixels_drawn + 1
        end
        return true
    end

    local function draw_line(x1: number, y1: number, x2: number, y2: number, color: Color, line_width: number?, alpha: number?)
        local clipped_result = ClippingSystem.clip_line(clip_stack, x1, y1, x2, y2)
        if not clipped_result then return end
        
        x1, y1, x2, y2 = clipped_result, clipped_result, clipped_result, clipped_result
        line_width = line_width or 1
        
        local dx = math.abs(x2 - x1)
        local dy = math.abs(y2 - y1)
        local sx = x1 < x2 and 1 or -1
        local sy = y1 < y2 and 1 or -1
        local err = dx - dy
        
        local function draw_thick_pixel(px: number, py: number)
            local half_width = math.floor(line_width :: number / 2)
            local half_width_plus = math.floor((line_width :: number - 1) / 2)
            for dx_offset = -half_width, half_width_plus do
                for dy_offset = -half_width, half_width_plus do
                    draw_pixel(px + dx_offset, py + dy_offset, color, alpha)
                end
            end
        end
        
        while true do
            draw_thick_pixel(x1, y1)
            
            if x1 == x2 and y1 == y2 then
                break
            end
            
            local e2 = 2 * err
            if e2 > -dy then
                err = err - dy
                x1 = x1 + sx
            end
            if e2 < dx then
                err = err + dx
                y1 = y1 + sy
            end
        end
        
        if dirty_rects then
            local min_x, min_y = math.min(x1, x2), math.min(y1, y2)
            local max_x, max_y = math.max(x1, x2), math.max(y1, y2)
            local lw = line_width :: number
            DirtyRectangles.mark_dirty(dirty_rects, min_x - lw, min_y - lw,
                                     (max_x - min_x) + lw * 2, (max_y - min_y) + lw * 2)
        end
        
        if debug_mode then
            debug_info.draw_calls = debug_info.draw_calls + 1
        end
    end

    local function draw_horizontal_line(y: number, color: Color)
        if y < 0 or y >= height then return end
        
        local first_byte = bit32.band(color, 0xFF)
        local second_byte = bit32.band(bit32.rshift(color, 8), 0xFF)
        local third_byte = bit32.band(bit32.rshift(color, 16), 0xFF)
        
        local start_offset = y * width * 4
        
        if first_byte == second_byte and second_byte == third_byte then
            buffer.fill(back_buffer, start_offset, first_byte, width * 4)
        else
            for x = 0, width - 1, 64 do
                local chunk_width = math.min(64, width - x)
                for i = 0, chunk_width - 1 do
                    buffer.writeu32(back_buffer, start_offset + (x + i) * 4, color)
                end
            end
        end
        
        if debug_mode then
            debug_info.draw_calls = debug_info.draw_calls + 1
            debug_info.pixels_drawn = debug_info.pixels_drawn + width
        end
    end

    local function clear(color: Color)
        local first_byte = bit32.band(color, 0xFF)
        local second_byte = bit32.band(bit32.rshift(color, 8), 0xFF)
        local third_byte = bit32.band(bit32.rshift(color, 16), 0xFF)
        
        if first_byte == second_byte and second_byte == third_byte then
            buffer.fill(back_buffer, 0, first_byte, width * height * 4)
        else
            local total_pixels = width * height
            for i = 0, total_pixels - 1, 1024 do
                local chunk_size = math.min(1024, total_pixels - i)
                for j = 0, chunk_size - 1 do
                    buffer.writeu32(back_buffer, (i + j) * 4, color)
                end
            end
        end
        
        if dirty_rects then
            DirtyRectangles.mark_dirty(dirty_rects, 0, 0, width, height)
        end
        
        if debug_mode then
            debug_info.draw_calls = debug_info.draw_calls + 1
        end
    end

    local function draw_circle(centerx: number, centery: number, radius: number, color: Color, filled: boolean, alpha: number?)
        radius = math.abs(radius)
        centerx = math.floor(centerx)
        centery = math.floor(centery)
        
        if radius < 1 then
            draw_pixel(centerx, centery, color, alpha)
            return
        end
        
        local radius_sq = radius * radius
        local min_x = math.floor(centerx - radius)
        local max_x = math.floor(centerx + radius)
        local min_y = math.floor(centery - radius)
        local max_y = math.floor(centery + radius)
        
        if filled then
            for y = min_y, max_y do
                local dy = y - centery
                local dy_sq = dy * dy
                
                local discriminant = radius_sq - dy_sq
                if discriminant >= 0 then
                    local half_width = math.sqrt(discriminant)
                    local x_start = math.floor(centerx - half_width)
                    local x_end = math.floor(centerx + half_width)
                    
                    for x = x_start, x_end do
                        draw_pixel(x, y, color, alpha)
                    end
                end
            end
        else
            local x = 0
            local y = math.floor(radius)
            local d = 3 - 2 * radius
            
            local function draw_circle_points(cx: number, cy: number, x: number, y: number)
                draw_pixel(cx + x, cy + y, color, alpha)
                draw_pixel(cx - x, cy + y, color, alpha)
                draw_pixel(cx + x, cy - y, color, alpha)
                draw_pixel(cx - x, cy - y, color, alpha)
                draw_pixel(cx + y, cy + x, color, alpha)
                draw_pixel(cx - y, cy + x, color, alpha)
                draw_pixel(cx + y, cy - x, color, alpha)
                draw_pixel(cx - y, cy - x, color, alpha)
            end
            
            draw_circle_points(centerx, centery, x, y)
            
            while y >= x do
                x = x + 1
                
                if d > 0 then
                    y = y - 1
                    d = d + 4 * (x - y) + 10
                else
                    d = d + 4 * x + 6
                end
                
                draw_circle_points(centerx, centery, x, y)
            end
        end
        
        if dirty_rects then
            DirtyRectangles.mark_dirty(dirty_rects, centerx - radius, centery - radius, 
                                    radius * 2, radius * 2)
        end
        
        if debug_mode then
            debug_info.draw_calls = debug_info.draw_calls + 1
        end
    end

    local function draw_polygon(points: Polygon, color: Color, filled: boolean, alpha: number?)
        if #points < 3 then
            error("Polygon must have at least 3 points")
        end
        
        local minx, miny = math.huge, math.huge
        local maxx, maxy = -math.huge, -math.huge
        
        for _, point in ipairs(points) do
            minx = math.min(minx, point[1])
            miny = math.min(miny, point[2])
            maxx = math.max(maxx, point[1])
            maxy = math.max(maxy, point[2])
        end
        
        local clipped_result = ClippingSystem.clip_rect(clip_stack, minx, miny, maxx - minx, maxy - miny)
        if not clipped_result then return end
        
        minx = math.max(0, math.floor(minx))
        miny = math.max(0, math.floor(miny))
        maxx = math.min(width - 1, math.floor(maxx))
        maxy = math.min(height - 1, math.floor(maxy))
        
        if filled then
            for y = miny, maxy do
                local active_edges = MemoryPools.get_temp_array()
                for i = 1, #points do
                    local j = i % #points + 1
                    local y1, y2 = points[i][2], points[j][2]
                    if (y1 <= y and y2 > y) or (y2 <= y and y1 > y) then
                        local x = points[i][1] + (y - y1) * (points[j][1] - points[i][1]) / (y2 - y1)
                        table.insert(active_edges, math.floor(x))
                    end
                end
                
                table.sort(active_edges)
                
                for i = 1, #active_edges - 1, 2 do
                    local x1 = math.max(minx, active_edges[i])
                    local x2 = math.min(maxx, active_edges[i + 1])
                    for x = x1, x2 do
                        draw_pixel(x, y, color, alpha)
                    end
                end
                
                MemoryPools.return_temp_array(active_edges)
            end
        else
            for i = 1, #points do
                local j = i % #points + 1
                draw_line(points[i][1], points[i][2], points[j][1], points[j][2], color, 1, alpha)
            end
        end
        
        if dirty_rects then
            DirtyRectangles.mark_dirty(dirty_rects, minx, miny, maxx - minx, maxy - miny)
        end
        
        if debug_mode then
            debug_info.draw_calls = debug_info.draw_calls + 1
        end
    end

    local function present()
        if dirty_rects then
            local optimized = DirtyRectangles.optimize_dirty_rects(dirty_rects, 10)
            debug_info.dirty_rects_active = #optimized
            
            for _, rect in ipairs(optimized) do
                if rect.marked then
                    local safe_x, safe_y, safe_w, safe_h, valid = safe_buffer_bounds(rect.x1, rect.y1, rect.x2 - rect.x1, rect.y2 - rect.y1)
                    
                    if valid and safe_w > 0 and safe_h > 0 then
                        for y = 0, safe_h - 1 do
                            local src_row_offset = ((safe_y + y) * width + safe_x) * 4
                            local dst_row_offset = src_row_offset
                            local row_bytes = safe_w * 4
                            
                            if src_row_offset >= 0 and dst_row_offset >= 0 and 
                               src_row_offset + row_bytes <= buffer.len(back_buffer) and
                               dst_row_offset + row_bytes <= buffer.len(framebuffer) then
                                buffer.copy(framebuffer, dst_row_offset, back_buffer, src_row_offset, row_bytes)
                            end
                        end
                    end
                end
            end
            
            DirtyRectangles.clear_dirty_rects(dirty_rects)
        else
            local buffer_size = width * height * 4
            if buffer.len(framebuffer) >= buffer_size and buffer.len(back_buffer) >= buffer_size then
                buffer.copy(framebuffer, 0, back_buffer, 0, buffer_size)
            end
        end
    end

    local function flush_batch()
        if #batch_system > 0 then
            BatchRenderer.execute_batch(batch_system, draw_pixel, draw_line)
            debug_info.batched_calls = debug_info.batched_calls + #batch_system
            BatchRenderer.clear_batch(batch_system)
        end
    end

    local function handle_events(callback: ((event: any) -> ())?)
        if not gfx.window_exists(framebuffer) then
            return {}
        end
        
        local events = gfx.get_window_events(framebuffer)
        if callback then
            for _, event in ipairs(events) do
                callback(event)
            end
        end
        return events
    end

    local function get_cursor_position(): (number, number)
        if not gfx.window_exists(framebuffer) then
            return 0, 0
        end
        return gfx.get_cursor_position(framebuffer)
    end

    local function resize(new_width: number, new_height: number)
        if type(new_width) ~= "number" or new_width <= 0 then
            error("New width must be a positive number")
        end
        if type(new_height) ~= "number" or new_height <= 0 then
            error("New height must be a positive number")
        end
        
        if gfx.window_exists(framebuffer) then
            gfx.set_window_size(framebuffer, new_width, new_height)
            width = new_width
            height = new_height
            
            back_buffer = buffer.create(width * height * 4)
            
            if dirty_rects then
                dirty_rects = DirtyRectangles.create_dirty_system(width, height)
            end
            
            spatial_tree = spatial.create_quadtree(width, height)
        end
    end

    local function is_window_open(): boolean
        return framebuffer ~= nil and gfx.window_exists(framebuffer)
    end

    local function get_debug_info()
        debug_info.memory_pools = MemoryPools.get_all_pool_stats()
        return {
            draw_calls = debug_info.draw_calls,
            pixels_drawn = debug_info.pixels_drawn,
            batched_calls = debug_info.batched_calls,
            dirty_rects_active = debug_info.dirty_rects_active,
            window_size = {width = width, height = height},
            buffer_status = framebuffer and gfx.window_exists(framebuffer) and "Active" or "Inactive",
            runtime = os.clock() - debug_info.start_time,
            memory_pools = debug_info.memory_pools
        }
    end

    return {
        buffer = framebuffer,
        width = width,
        height = height,
        
        rgb = colorlib.rgb,
        rgba = colorlib.rgba,
        hsv_to_rgb = colorlib.hsv_to_rgb,
        
        Black = colorlib.Black,
        White = colorlib.White,
        Red = colorlib.Red,
        Green = colorlib.Green,
        Blue = colorlib.Blue,
        Gray = colorlib.Gray,
        Yellow = colorlib.Yellow,
        Cyan = colorlib.Cyan,
        Magenta = colorlib.Magenta,
        Orange = colorlib.Orange,
        Purple = colorlib.Purple,
        Transparent = colorlib.Transparent,
        
        draw_pixel = draw_pixel,
        get_pixel = get_pixel,
        draw_line = draw_line,
        draw_horizontal_line = draw_horizontal_line,
        clear = clear,
        draw_circle = draw_circle,
        draw_polygon = draw_polygon,
        present = present,
        flush_batch = flush_batch,
        
        draw_rect = function(x: number, y: number, w: number, h: number, color: Color, filled: boolean?, alpha: number?)
            shapes.draw_rect(draw_pixel, x, y, w, h, color, filled or false, alpha)
        end,
        
        draw_rounded_rect = function(x: number, y: number, w: number, h: number, radius: number, color: Color, filled: boolean?, alpha: number?)
            shapes.draw_rounded_rect(draw_pixel, x, y, w, h, radius, color, filled or false, alpha)
        end,
        
        draw_ellipse = function(cx: number, cy: number, rx: number, ry: number, color: Color, filled: boolean?, alpha: number?)
            shapes.draw_ellipse(draw_pixel, cx, cy, rx, ry, color, filled or false, alpha)
        end,
        
        draw_bezier_curve = function(p0: Point, p1: Point, p2: Point, p3: Point, color: Color, segments: number?, alpha: number?)
            shapes.draw_bezier_curve(draw_pixel, p0, p1, p2, p3, color, segments, alpha)
        end,
        
        draw_arc = function(cx: number, cy: number, radius: number, start_angle: number, end_angle: number, color: Color, alpha: number?)
            shapes.draw_arc(draw_pixel, cx, cy, radius, start_angle, end_angle, color, alpha)
        end,
        
        draw_linear_gradient = function(x: number, y: number, w: number, h: number, gradient: LinearGradient, alpha: number?)
            shapes.draw_linear_gradient(draw_pixel, x, y, w, h, gradient, alpha)
        end,
        
        draw_radial_gradient = function(x: number, y: number, w: number, h: number, gradient: RadialGradient, alpha: number?)
            shapes.draw_radial_gradient(draw_pixel, x, y, w, h, gradient, alpha)
        end,
        
        flood_fill = function(x: number, y: number, new_color: Color, alpha: number?)
            shapes.flood_fill(draw_pixel, get_pixel, x, y, new_color, width, height, alpha)
        end,
        
        push_clip_rect = function(x: number, y: number, w: number, h: number)
            ClippingSystem.push_clip_rect(clip_stack, x, y, w, h)
        end,
        
        pop_clip_rect = function()
            ClippingSystem.pop_clip_rect(clip_stack)
        end,
        
        blend_multiply = colorlib.blend_multiply,
        blend_screen = colorlib.blend_screen,
        blend_overlay = colorlib.blend_overlay,
        
        batch_pixel = function(x: number, y: number, color: Color, alpha: number?)
            BatchRenderer.add_to_batch(batch_system, "pixel", color, {x = x, y = y}, alpha)
        end,
        
        batch_line = function(x1: number, y1: number, x2: number, y2: number, color: Color, line_width: number?, alpha: number?)
            BatchRenderer.add_to_batch(batch_system, "line", color, {x1 = x1, y1 = y1, x2 = x2, y2 = y2, width = line_width or 1}, alpha)
        end,
        
        handle_events = handle_events,
        get_cursor_position = get_cursor_position,
        resize = resize,
        is_window_open = is_window_open,
        get_debug_info = get_debug_info
    }
end

local function set_global_debug_mode(enabled: boolean)
    set_global_debug_mode = enabled
end

Renderer.create = create
Renderer.set_global_debug_mode = set_global_debug_mode

return Renderer