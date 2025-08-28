# Event system documentation, can also be accessed at the main runluau repo

## event handling functions

```lua
function renderer.handle_events(callback: ((event: gfx_event) -> ())?): {gfx_event}
-- processes all pending window events. if callback provided, calls it for each event.
-- returns array of all events that occurred this frame.

function renderer.get_cursor_position(): (number, number)
-- returns current mouse cursor position relative to window.
-- returns (x, y) coordinates in pixels.
```

## event types

### input events
input events triggered by keyboard keys and mouse buttons being pressed or released.

```lua
type InputEvent = {
    event_type: "input",
    down: boolean,        -- true when pressed down, false when released
    input: gfx_input_type -- specific key or button that was pressed
}
```

### scroll events
scroll events triggered by mouse wheel movement.

```lua
type ScrollEvent = {
    event_type: "scroll",
    delta: number         -- scroll amount (positive = up/away, negative = down/toward)
}                        -- typically in increments of 120 or -120
```

## available input types

### mouse buttons
- `"LeftMouseButton"` - left mouse button
- `"RightMouseButton"` - right mouse button  
- `"MiddleMouseButton"` - middle mouse button (scroll wheel click)
- `"XButton1"` - extra mouse button 1
- `"XButton2"` - extra mouse button 2

### numbers
- `"0"` through `"9"` - number keys on main keyboard

### letters
- `"A"` through `"Z"` - letter keys (always uppercase regardless of shift/caps)

### function keys
- `"F1"` through `"F12"` - function keys

### numpad
- `"NumPad0"` through `"NumPad9"` - numeric keypad numbers
- `"NumPadMultiply"` - numpad * key
- `"NumPadAdd"` - numpad + key
- `"NumPadSeparator"` - numpad separator key
- `"NumPadSubtract"` - numpad - key
- `"NumPadDecimal"` - numpad . key
- `"NumPadDivide"` - numpad / key

### modifier keys
- `"Shift"` - either shift key
- `"LeftShift"` - left shift key specifically
- `"RightShift"` - right shift key specifically
- `"Control"` - either control key
- `"LeftControl"` - left control key specifically
- `"RightControl"` - right control key specifically
- `"Alt"` - either alt key
- `"LeftAlt"` - left alt key specifically
- `"RightAlt"` - right alt key specifically

### arrow keys
- `"LeftArrow"` - left arrow key
- `"UpArrow"` - up arrow key
- `"RightArrow"` - right arrow key
- `"DownArrow"` - down arrow key

### navigation keys
- `"Home"` - home key
- `"End"` - end key
- `"PageUp"` - page up key
- `"PageDown"` - page down key
- `"Insert"` - insert key
- `"Delete"` - delete key

### special keys
- `"Space"` - space bar
- `"Tab"` - tab key
- `"Enter"` - enter/return key
- `"Backspace"` - backspace key
- `"Escape"` - escape key
- `"Clear"` - clear key
- `"Select"` - select key

### lock keys
- `"CapsLock"` - caps lock key
- `"NumLock"` - num lock key
- `"ScrollLock"` - scroll lock key

### system keys
- `"LeftWindows"` - left windows/cmd key
- `"RightWindows"` - right windows/cmd key
- `"Applications"` - applications/menu key
- `"PrintScreen"` - print screen key
- `"Pause"` - pause/break key
- `"Execute"` - execute key
- `"Print"` - print key
- `"Help"` - help key
- `"Sleep"` - sleep key

### media keys
- `"VolumeMute"` - volume mute key
- `"VolumeDown"` - volume down key
- `"VolumeUp"` - volume up key
- `"MediaNextTrack"` - next track key
- `"MediaPrevTrack"` - previous track key
- `"MediaStop"` - stop media key
- `"MediaPlayPause"` - play/pause media key

### punctuation keys
- `"Semicolon"` - ; key
- `"Plus"` - + key
- `"Minus"` - - key
- `"Comma"` - , key
- `"Period"` - . key
- `"Slash"` - / key
- `"Tilde"` - ~ key
- `"OpenBracket"` - [ key
- `"CloseBracket"` - ] key
- `"Backslash"` - \ key
- `"Quote"` - ' key

## usage examples

### basic event handling
```lua
while renderer.is_window_open() do
    local events = renderer.handle_events()
    
    for _, event in ipairs(events) do
        if event.event_type == "input" then
            if event.input == "Escape" and event.down then
                -- handle escape key press
                break
            elseif event.input == "LeftMouseButton" and event.down then
                -- handle left mouse click
                local x, y = renderer.get_cursor_position()
                print("clicked at:", x, y)
            end
        elseif event.event_type == "scroll" then
            -- handle mouse wheel scroll
            print("scrolled:", event.delta > 0 and "up" or "down")
        end
    end
    
    renderer.present()
end
```

### event callback style
```lua
renderer.handle_events(function(event)
    if event.event_type == "input" and event.down then
        print("key pressed:", event.input)
    end
end)
```

### key state tracking
```lua
local keys_down = {}

renderer.handle_events(function(event)
    if event.event_type == "input" then
        keys_down[event.input] = event.down
    end
end)

-- check if key is currently held down
if keys_down["W"] then
    -- move forward
end
```