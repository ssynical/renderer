# api reference

complete documentation for the runluau renderer engine.

## creating a renderer

```lua
local renderer = Renderer.create(width, height, title?, options?)
```

**parameters:**
- `width: number` - window width in pixels
- `height: number` - window height in pixels  
- `title: string?` - window title (optional)
- `options: RendererOptions?` - configuration options (optional)

**options:**
```lua
{
    pixel_size: number?,          -- pixel scaling factor (default: 1)
    debug_mode: boolean?,         -- enable performance tracking (default: false)
    enable_dirty_rects: boolean?, -- optimize redraws (default: true)
    max_batch_size: number?       -- batch operation limit (default: 1000)
}
```

## drawing functions

### basic shapes

```lua
renderer.draw_pixel(x, y, color, alpha?)
renderer.draw_line(x1, y1, x2, y2, color, line_width?, alpha?)
renderer.draw_horizontal_line(y, color)
renderer.draw_circle(centerx, centery, radius, color, filled, alpha?)
renderer.draw_polygon(points, color, filled, alpha?)
```

### extended shapes

```lua
renderer.draw_rect(x, y, width, height, color, filled?, alpha?)
renderer.draw_rounded_rect(x, y, width, height, radius, color, filled?, alpha?)
renderer.draw_ellipse(cx, cy, rx, ry, color, filled?, alpha?)
renderer.draw_arc(cx, cy, radius, start_angle, end_angle, color, alpha?)
renderer.draw_bezier_curve(p0, p1, p2, p3, color, segments?, alpha?)
```

### gradients

```lua
renderer.draw_linear_gradient(x, y, width, height, gradient, alpha?)
renderer.draw_radial_gradient(x, y, width, height, gradient, alpha?)
```

**gradient format:**
```lua
-- linear gradient
{
    x1 = start_x, y1 = start_y,
    x2 = end_x, y2 = end_y,
    stops = {
        {position = 0.0, color = renderer.Red},
        {position = 1.0, color = renderer.Blue}
    }
}

-- radial gradient  
{
    cx = center_x, cy = center_y, r = radius,
    stops = {
        {position = 0.0, color = renderer.White},
        {position = 1.0, color = renderer.Black}
    }
}
```

## window management

```lua
renderer.clear(color)                    -- clear screen with color
renderer.present()                       -- display frame to window
renderer.resize(new_width, new_height)   -- resize window
renderer.is_window_open()               -- check if window is open
```

## event handling

```lua
local events = renderer.handle_events(callback?)
local x, y = renderer.get_cursor_position()
```

see [events.md](events.md) for detailed event documentation.

## color functions

```lua
renderer.rgb(r, g, b)           -- create rgb color (0-255)
renderer.rgba(r, g, b, a)       -- create rgba color (0-255)
renderer.hsv_to_rgb(h, s, v)    -- convert hsv to rgb
```

### preset colors

```lua
renderer.Black       -- 0x000000
renderer.White       -- 0xFFFFFF
renderer.Red         -- 0xFF0000
renderer.Green       -- 0x00FF00
renderer.Blue        -- 0x0000FF
renderer.Gray        -- 0x808080
renderer.Yellow      -- 0xFFFF00
renderer.Cyan        -- 0x00FFFF
renderer.Magenta     -- 0xFF00FF
renderer.Orange      -- 0xFFA500
renderer.Purple      -- 0x800080
renderer.Transparent -- 0x00000000
```

## advanced features

### color blending

```lua
renderer.blend_multiply(color1, color2)
renderer.blend_screen(color1, color2)  
renderer.blend_overlay(color1, color2)
```

### clipping

```lua
renderer.push_clip_rect(x, y, width, height)  -- enable clipping
renderer.pop_clip_rect()                      -- disable clipping
```

### batching

```lua
renderer.batch_pixel(x, y, color, alpha?)
renderer.batch_line(x1, y1, x2, y2, color, line_width?, alpha?)
renderer.flush_batch()  -- execute all batched operations
```

### utilities

```lua
renderer.get_pixel(x, y)        -- get pixel color at position
renderer.flood_fill(x, y, new_color, alpha?)  -- flood fill from point
renderer.get_debug_info()       -- get performance statistics
```

## debug info structure

```lua
{
    draw_calls: number,           -- total draw operations
    pixels_drawn: number,         -- total pixels modified
    batched_calls: number,        -- operations in batch
    dirty_rects_active: number,   -- active dirty rectangles
    window_size: {width, height}, -- current window dimensions
    buffer_status: string,        -- "Active" or "Inactive"
    runtime: number,             -- seconds since creation
    memory_pools: table          -- memory pool statistics
}
```

## error handling

the renderer will throw errors for:
- invalid dimensions (width/height <= 0)
- malformed polygons (< 3 points)
- buffer creation failures

most drawing functions will silently clip to window bounds instead of erroring.