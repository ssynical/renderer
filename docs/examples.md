# examples

code samples and tutorials for the runluau renderer engine.

## basic setup

```lua
local Renderer = require("src/renderer")

local WIDTH = 800
local HEIGHT = 600
local renderer = Renderer.create(WIDTH, HEIGHT, "my app")

-- main loop
while renderer.is_window_open() do
    renderer.clear(renderer.Black)
    
    -- your drawing code here
    
    renderer.present()
    task.wait(1/60)
end
```

## bouncing circle

```lua
local WIDTH = 800
local HEIGHT = 600
local renderer = Renderer.create(WIDTH, HEIGHT, "bouncing circle")

local circle = {
    x = WIDTH / 2,
    y = HEIGHT / 2,
    radius = 50,
    dx = 5,
    dy = 4
}

while renderer.is_window_open() do
    renderer.clear(renderer.White)
    
    -- move circle
    circle.x = circle.x + circle.dx
    circle.y = circle.y + circle.dy
    
    -- bounce off edges
    if circle.x - circle.radius <= 0 or circle.x + circle.radius >= WIDTH then
        circle.dx = -circle.dx
    end
    if circle.y - circle.radius <= 0 or circle.y + circle.radius >= HEIGHT then
        circle.dy = -circle.dy
    end
    
    renderer.draw_circle(circle.x, circle.y, circle.radius, renderer.Blue, true)
    renderer.present()
    task.wait(1/60)
end
```

## event handling

```lua
local renderer = Renderer.create(800, 600, "events demo")
local mouse_x, mouse_y = 0, 0
local mouse_down = false

while renderer.is_window_open() do
    -- handle events
    local events = renderer.handle_events()
    for _, event in ipairs(events) do
        if event.event_type == "input" then
            if event.input == "LeftMouseButton" then
                mouse_down = event.down
            elseif event.input == "Escape" and event.down then
                break
            end
        end
    end
    
    -- get mouse position
    mouse_x, mouse_y = renderer.get_cursor_position()
    
    renderer.clear(renderer.Gray)
    
    -- draw circle at mouse if pressed
    if mouse_down then
        renderer.draw_circle(mouse_x, mouse_y, 20, renderer.Red, true)
    else
        renderer.draw_circle(mouse_x, mouse_y, 20, renderer.Blue, false)
    end
    
    renderer.present()
    task.wait(1/60)
end
```

## drawing with gradients

```lua
local renderer = Renderer.create(800, 600, "gradients")

local linear_grad = {
    x1 = 0, y1 = 0, x2 = 800, y2 = 0,
    stops = {
        {position = 0.0, color = renderer.Red},
        {position = 0.5, color = renderer.Green},
        {position = 1.0, color = renderer.Blue}
    }
}

local radial_grad = {
    cx = 400, cy = 300, r = 200,
    stops = {
        {position = 0.0, color = renderer.White},
        {position = 1.0, color = renderer.Black}
    }
}

while renderer.is_window_open() do
    renderer.clear(renderer.Black)
    
    -- linear gradient background
    renderer.draw_linear_gradient(0, 0, 800, 300, linear_grad)
    
    -- radial gradient circle
    renderer.draw_radial_gradient(200, 450, 400, 300, radial_grad)
    
    renderer.present()
    task.wait(1/60)
end
```

## particle system

```lua
local renderer = Renderer.create(800, 600, "particles")

local particles = {}

-- create particles
for i = 1, 100 do
    table.insert(particles, {
        x = math.random(0, 800),
        y = math.random(0, 600),
        dx = (math.random() - 0.5) * 4,
        dy = (math.random() - 0.5) * 4,
        life = 1.0,
        decay = math.random() * 0.02 + 0.005
    })
end

while renderer.is_window_open() do
    renderer.clear(renderer.Black)
    
    -- update and draw particles
    for i = #particles, 1, -1 do
        local p = particles[i]
        
        -- update position
        p.x = p.x + p.dx
        p.y = p.y + p.dy
        p.life = p.life - p.decay
        
        -- remove dead particles
        if p.life <= 0 then
            table.remove(particles, i)
        else
            -- draw particle with alpha based on life
            local alpha = p.life
            local color = renderer.rgba(255, 255, 255, math.floor(alpha * 255))
            renderer.draw_circle(p.x, p.y, 2, color, true)
        end
    end
    
    -- spawn new particles
    if #particles < 100 then
        table.insert(particles, {
            x = math.random(0, 800),
            y = math.random(0, 600),
            dx = (math.random() - 0.5) * 4,
            dy = (math.random() - 0.5) * 4,
            life = 1.0,
            decay = math.random() * 0.02 + 0.005
        })
    end
    
    renderer.present()
    task.wait(1/60)
end
```

## interactive drawing

```lua
local renderer = Renderer.create(800, 600, "paint")

local brush_size = 5
local current_color = renderer.Red
local mouse_down = false
local last_x, last_y = 0, 0

-- create canvas
renderer.clear(renderer.White)

while renderer.is_window_open() do
    local events = renderer.handle_events()
    
    for _, event in ipairs(events) do
        if event.event_type == "input" then
            if event.input == "LeftMouseButton" then
                mouse_down = event.down
                if event.down then
                    last_x, last_y = renderer.get_cursor_position()
                end
            elseif event.input == "1" and event.down then
                current_color = renderer.Red
            elseif event.input == "2" and event.down then
                current_color = renderer.Green
            elseif event.input == "3" and event.down then
                current_color = renderer.Blue
            elseif event.input == "Space" and event.down then
                renderer.clear(renderer.White)
            end
        elseif event.event_type == "scroll" then
            brush_size = math.max(1, math.min(20, brush_size + (event.delta > 0 and 1 or -1)))
        end
    end
    
    if mouse_down then
        local x, y = renderer.get_cursor_position()
        
        -- draw line from last position to current
        renderer.draw_line(last_x, last_y, x, y, current_color, brush_size)
        
        last_x, last_y = x, y
    end
    
    -- show brush preview
    if not mouse_down then
        local x, y = renderer.get_cursor_position()
        renderer.draw_circle(x, y, brush_size / 2, current_color, false, 0.5)
    end
    
    renderer.present()
    task.wait(1/60)
end
```

## performance tips

1. **batch similar operations:**
```lua
-- instead of individual pixels
for i = 1, 1000 do
    renderer.draw_pixel(x + i, y, color)
end

-- use batching
for i = 1, 1000 do
    renderer.batch_pixel(x + i, y, color)
end
renderer.flush_batch()
```

2. **use appropriate shapes:**
```lua
-- for horizontal lines, use the optimized function
renderer.draw_horizontal_line(y, color)

-- instead of
renderer.draw_line(0, y, width, y, color)
```

3. **minimize clear() calls:**
```lua
-- clear once per frame, not per object
renderer.clear(background_color)
-- draw all objects
renderer.present()
```

4. **use clipping for complex scenes:**
```lua
renderer.push_clip_rect(visible_area_x, visible_area_y, visible_width, visible_height)
-- draw only visible objects
renderer.pop_clip_rect()
```