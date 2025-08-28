runluau renderer engine
======================

hey! this is a simple graphics renderer written in luau. it's pretty straightforward to use and lets you draw basic shapes and handle window events.

what can it do?
--------------
- create windows with custom sizes
- draw pixels, lines, circles, and polygons
- handle mouse and window events
- debug mode for performance tracking
- rgb color support with some preset colors
- efficient buffer operations for better performance

basic usage
----------
```lua
local renderer = Renderer.create(800, 600, "my window")

-- draw a red circle
renderer.draw_circle(400, 300, 50, renderer.Red, true)

-- main loop
while renderer.is_window_open() do
    renderer.handle_events()
    task.wait(1/60)  -- cap at ~60fps, not including a task.wait will crash the program
end
```

installation
-----------
just drop the renderer.luau file into your project and require it:
```lua
local Renderer = require("renderer")
```
you WILL need a program named ['runluau'](https://github.com/plusgiant5/runluau) to run this, and the gfx [plugin](https://github.com/plusgiant5/runluau-plugins) for gfx to be exposed.
more information on that in their respective repos

available functions
-----------------
drawing:
- draw_pixel(x, y, color)
- draw_line(x1, y1, x2, y2, color, line_width?)
- draw_horizontal_line(y, color)
- draw_circle(centerx, centery, radius, color, filled)
- draw_polygon(points, color, filled)
- clear(color)

window stuff:
- create(width, height, title?, options?)
- handle_events(callback?)
- get_cursor_position()
- resize(width, height)
- is_window_open()

other cool things:
- rgb(r, g, b) - make custom colors
- get_debug_info() - see how your renderer is performing
- set_global_debug_mode(enabled) - turn on performance tracking

preset colors
------------
we've got some basic colors ready to use:
- Black
- White
- Red
- Green
- Blue
- Gray
- Yellow
- Cyan
- Magenta
- Orange
- Purple
- Transparent

performance tips
---------------
- use draw_horizontal_line() instead of individual pixels when you can
- the clear() function is optimized for solid colors
- bigger pixel_size in options means better performance (but chunkier graphics)
- debug mode is useful but adds overhead, so turn it off in production

example: bouncing circle
----------------------
```lua
local WIDTH = 800
local HEIGHT = 600
local renderer = Renderer.create(WIDTH, HEIGHT, "bounce")

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
    task.wait(1/60)
end
```

have fun!
-------
that's pretty much it! play around with it and make something cool. if you run into any issues, open one, or if you want to contribute, feel free to pr.

made with love 🖤
last updated: 28.8.2025
