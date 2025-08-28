--!strict

export type Color = number
export type Point = {number}
export type Polygon = {Point}
export type Rect = {x: number, y: number, width: number, height: number}
export type Circle = {x: number, y: number, radius: number}

export type RendererOptions = {
    pixel_size: number?,
    debug_mode: boolean?,
    enable_dirty_rects: boolean?,
    max_batch_size: number?
}

export type DebugInfo = {
    draw_calls: number,
    pixels_drawn: number,
    batched_calls: number,
    dirty_rects_active: number,
    start_time: number,
    memory_pools: {[string]: number}
}

export type WindowBuffer = buffer & {
    __windowbuffer: true
}

export type DirtyRect = {
    x1: number, y1: number, x2: number, y2: number,
    marked: boolean
}

export type BatchedCall = {
    type: string,
    color: Color,
    alpha: number?,
    data: any
}

export type MemoryPool<T> = {
    available: {T},
    create_new: () -> T,
    reset_item: (T) -> ()
}

export type GradientStop = {
    position: number,
    color: Color
}

export type LinearGradient = {
    x1: number, y1: number, x2: number, y2: number,
    stops: {GradientStop}
}

export type RadialGradient = {
    cx: number, cy: number, r: number,
    stops: {GradientStop}
}

export type TextureData = {
    width: number,
    height: number,
    pixels: buffer
}

export type SpatialNode = {
    bounds: Rect,
    items: {any},
    children: {SpatialNode}?,
    depth: number
}

export type ClipRect = {
    x: number, y: number, width: number, height: number,
    active: boolean
}

export type Transform = {
    m11: number, m12: number, m13: number,
    m21: number, m22: number, m23: number,
    m31: number, m32: number, m33: number
}

return {}