--[[>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
||                                                                              ||
||                  <// runluau renderer engine //>                             ||
||                                                                              ||
||            coded with real hands by me, with love                            ||
||            alive since 06.12.2024 | last big update: 28.1.2025              ||
||                                                                              ||
>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>]]--

--!strict
--!native
--!optimize 2

type Color = number
type Point = {number}
type Polygon = {Point}
type RendererOptions = {
    pixel_size: number?,
    debug_mode: boolean?
}
type DebugInfo = {
    draw_calls: number,
    pixels_drawn: number,
    start_time: number
}
type WindowBuffer = buffer & {
    __windowbuffer: true
}

local Renderer = {}

local set_global_debug_mode = false

function Renderer.set_global_debug_mode(enabled: boolean)
    set_global_debug_mode = enabled
end


local function rgb(r: number, g: number, b: number): Color
    local function clamp(v: number): number
        return math.max(0, math.min(255, math.floor(v)))
    end
    
    return bit32.bor(
        bit32.band(clamp(r), 0xFF),
        bit32.lshift(bit32.band(clamp(g), 0xFF), 8),
        bit32.lshift(bit32.band(clamp(b), 0xFF), 16)
    )
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


local Black = 0x000000
local White = 0xFFFFFF
local Red = 0x0000FF
local Green = 0x00FF00
local Blue = 0xFF0000
local Gray = 0x808080
local Yellow = 0x00FFFF
local Cyan = 0xFFFF00
local Magenta = 0xFF00FF
local Orange = 0x00A6FF
local Purple = 0x800080
local Transparent = 0x000000

local function create(width: number, height: number, title: string?, options: RendererOptions?): {
    buffer: WindowBuffer,
    width: number,
    height: number,
    rgb: (number, number, number) -> Color,
    Black: Color,
    White: Color,
    Red: Color,
    Green: Color,
    Blue: Color,
    Gray: Color,
    Yellow: Color,
    Cyan: Color,
    Magenta: Color,
    Orange: Color,
    Purple: Color,
    Transparent: Color,
    draw_pixel: (number, number, Color) -> boolean,
    draw_line: (number, number, number, number, Color, number?) -> (),
    draw_horizontal_line: (number, Color) -> (),
    clear: (Color) -> (),
    draw_circle: (number, number, number, Color, boolean) -> (),
    draw_polygon: (Polygon, Color, boolean) -> (),
    handle_events: ((event: gfx_event) -> ()?) -> {gfx_event},
    get_cursor_position: () -> (number, number),
    resize: (number, number) -> (),
    is_window_open: () -> boolean,
    get_debug_info: () -> {[string]: any}
}
    if type(width) ~= "number" or width <= 0 then
        error("Width must be a positive number")
    end
    if type(height) ~= "number" or height <= 0 then
        error("Height must be a positive number")
    end
    
    options = options or {}
    local pixel_size = options.pixel_size or 1
    local debug_mode = options.debug_mode or set_global_debug_mode
    local debug_info: DebugInfo = {
        draw_calls = 0,
        pixels_drawn = 0,
        start_time = os.clock()
    }
    
    local framebuffer = gfx.create_window(width, height, title, pixel_size) :: WindowBuffer
    if not framebuffer then
        error("Failed to create window buffer")
    end

    local function draw_pixel(x: number, y: number, color: Color, alpha: number?): boolean
        x, y = math.floor(x), math.floor(y)
        if x < 0 or x >= width or y < 0 or y >= height then
            return false
        end
        
        local offset = (y * width + x) * 4
        
        if alpha and alpha < 1 then
            local existing_color = buffer.readu32(framebuffer, offset)
            color = blend_colors(existing_color, color, alpha)
        end
        
        buffer.writeu32(framebuffer, offset, color)
        
        if debug_mode then
            debug_info.pixels_drawn = debug_info.pixels_drawn + 1
        end
        return true
    end

    local function draw_line(x1: number, y1: number, x2: number, y2: number, color: Color, line_width: number?, alpha: number?)
        line_width = line_width or 1
        
        local dx = math.abs(x2 - x1)
        local dy = math.abs(y2 - y1)
        local sx = x1 < x2 and 1 or -1
        local sy = y1 < y2 and 1 or -1
        local err = dx - dy
        
        local function draw_thick_pixel(x: number, y: number)
            local half_width = math.floor(line_width :: number/2)
            local half_width_plus = math.floor((line_width :: number-1)/2)
            for dx = -half_width, half_width_plus do
                for dy = -half_width, half_width_plus do
                    draw_pixel(x + dx, y + dy, color, alpha)
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
            buffer.fill(framebuffer, start_offset, first_byte, width * 4)
        else
            for x = 0, width - 1, 64 do
                local chunk_width = math.min(64, width - x)
                for i = 0, chunk_width - 1 do
                    buffer.writeu32(framebuffer, start_offset + (x + i) * 4, color)
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
            buffer.fill(framebuffer, 0, first_byte, width * height * 4)
        else
            local total_pixels = width * height
            for i = 0, total_pixels - 1, 1024 do
                local chunk_size = math.min(1024, total_pixels - i)
                for j = 0, chunk_size - 1 do
                    buffer.writeu32(framebuffer, (i + j) * 4, color)
                end
            end
        end
        
        if debug_mode then
            debug_info.draw_calls = debug_info.draw_calls + 1
        end
    end

    local function draw_circle(centerx: number, centery: number, radius: number, color: Color, filled: boolean, alpha: number?)
        radius = math.abs(radius)
        
        if radius < 1 then
            draw_pixel(centerx, centery, color, alpha)
            return
        end
        
        for x = -math.floor(radius), math.floor(radius) do
            local height = math.floor(math.sqrt(radius * radius - x * x))
            
            if filled then
                draw_line(centerx + x, centery - height, centerx + x, centery + height, color, 1, alpha)
            else
                draw_pixel(centerx + x, centery + height, color, alpha)
                draw_pixel(centerx + x, centery - height, color, alpha)
            end
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
        
        if maxx < 0 or minx >= width or maxy < 0 or miny >= height then
            return
        end
        
        minx = math.max(0, math.floor(minx))
        miny = math.max(0, math.floor(miny))
        maxx = math.min(width - 1, math.floor(maxx))
        maxy = math.min(height - 1, math.floor(maxy))
        
        if filled then
            for y = miny, maxy do
                local active_edges = {}
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
            end
        else
            for i = 1, #points do
                local j = i % #points + 1
                draw_line(points[i][1], points[i][2], points[j][1], points[j][2], color, 1, alpha)
            end
        end
        
        if debug_mode then
            debug_info.draw_calls = debug_info.draw_calls + 1
        end
    end

    local function handle_events(callback: ((event: gfx_event) -> ())?)
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
        end
    end

    local function get_debug_info(): {
        draw_calls: number,
        pixels_drawn: number,
        window_size: {width: number, height: number},
        buffer_status: string,
        runtime: number
    }
        return {
            draw_calls = debug_info.draw_calls,
            pixels_drawn = debug_info.pixels_drawn,
            window_size = {width = width, height = height},
            buffer_status = framebuffer and gfx.window_exists(framebuffer) and "Active" or "Inactive",
            runtime = os.clock() - debug_info.start_time
        }
    end
    local function is_window_open(): boolean
        return framebuffer ~= nil and gfx.window_exists(framebuffer)
    end

    return {
        buffer = framebuffer,
        width = width,
        height = height,
        
        rgb = rgb,
        
        Black = Black,
        White = White,
        Red = Red,
        Green = Green,
        Blue = Blue,
        Gray = Gray,
        Yellow = Yellow,
        Cyan = Cyan,
        Magenta = Magenta,
        Orange = Orange,
        Purple = Purple,
        Transparent = Transparent,
        
        draw_pixel = draw_pixel,
        draw_line = draw_line,
        draw_horizontal_line = draw_horizontal_line,
        clear = clear,
        draw_circle = draw_circle,
        draw_polygon = draw_polygon,
        
        handle_events = handle_events,
        get_cursor_position = get_cursor_position,
        resize = resize,
        is_window_open = is_window_open,
        
        get_debug_info = get_debug_info
    }
end

Renderer.create = create
Renderer.rgb = rgb
Renderer.set_global_debug_mode = set_global_debug_mode

return Renderer
