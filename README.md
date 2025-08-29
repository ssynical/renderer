# runluau renderer engine

a simple 2d graphics renderer written in luau. draw shapes, handle events, make things move.

## features

- window creation with custom sizes
- drawing primitives (pixels, lines, circles, polygons, rectangles)
- mouse and keyboard event handling
- performance optimization with dirty rectangles and batching
- color blending and gradients
- clipping system
- debug mode for performance tracking

## installation

1. install [runluau](https://github.com/plusgiant5/runluau)
2. install the gfx [plugin](https://github.com/plusgiant5/runluau-plugins)
3. drop the `src/` folder into your project
4. require the renderer:

```lua
local Renderer = require("src/renderer")
```

## quick start

```lua
local renderer = Renderer.create(800, 600, "my window")

-- draw a red circle
renderer.draw_circle(400, 300, 50, renderer.Red, true)

-- main loop
while renderer.is_window_open() do
    renderer.handle_events()
    renderer.present()
    task.wait(1/60)  -- cap at ~60fps
end
```

## documentation

- [api reference](docs/api.md) - complete function documentation
- [events system](docs/events.md) - mouse and keyboard event handling
- [examples](docs/examples.md) - code samples and tutorials

## performance tips

- use `renderer.present()` to display your frame
- batch operations when possible
- use dirty rectangles for partial screen updates
- turn off debug mode in production builds

## license

see [LICENSE](LICENSE) for details.

made with love 🖤  
last updated: 29.8.2025