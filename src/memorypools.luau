--!strict
--!native
--!optimize 2

local Types = require("types")

type MemoryPool<T> = Types.MemoryPool<T>
type Point = Types.Point
type BatchedCall = Types.BatchedCall

local MemoryPools = {}

local function create_pool<T>(create_new: () -> T, reset_item: (T) -> ()): MemoryPool<T>
    return {
        available = {},
        create_new = create_new,
        reset_item = reset_item
    }
end

local function get_from_pool<T>(pool: MemoryPool<T>): T
    if #pool.available > 0 then
        return table.remove(pool.available)
    end
    return pool.create_new()
end

local function return_to_pool<T>(pool: MemoryPool<T>, item: T)
    pool.reset_item(item)
    table.insert(pool.available, item)
end

local function get_pool_stats<T>(pool: MemoryPool<T>): number
    return #pool.available
end

local point_pool: MemoryPool<Point> = create_pool(
    function(): Point
        return {0, 0}
    end,
    function(point: Point)
        point[1] = 0
        point[2] = 0
    end
)

local batched_call_pool: MemoryPool<BatchedCall> = create_pool(
    function(): BatchedCall
        return {
            type = "",
            color = 0,
            alpha = nil,
            data = nil
        }
    end,
    function(call: BatchedCall)
        call.type = ""
        call.color = 0
        call.alpha = nil
        call.data = nil
    end
)

local polygon_pool: MemoryPool<{Point}> = create_pool(
    function(): {Point}
        return {}
    end,
    function(polygon: {Point})
        for i = #polygon, 1, -1 do
            return_to_pool(point_pool, polygon[i])
            polygon[i] = nil
        end
    end
)

local temp_arrays_pool: MemoryPool<{any}> = create_pool(
    function(): {any}
        return {}
    end,
    function(arr: {any})
        for i = #arr, 1, -1 do
            arr[i] = nil
        end
    end
)

local function get_point(x: number?, y: number?): Point
    local point = get_from_pool(point_pool)
    point[1] = x or 0
    point[2] = y or 0
    return point
end

local function return_point(point: Point)
    return_to_pool(point_pool, point)
end

local function get_batched_call(): BatchedCall
    return get_from_pool(batched_call_pool)
end

local function return_batched_call(call: BatchedCall)
    return_to_pool(batched_call_pool, call)
end

local function get_polygon(): {Point}
    return get_from_pool(polygon_pool)
end

local function return_polygon(polygon: {Point})
    return_to_pool(polygon_pool, polygon)
end

local function get_temp_array(): {any}
    return get_from_pool(temp_arrays_pool)
end

local function return_temp_array(arr: {any})
    return_to_pool(temp_arrays_pool, arr)
end

local function get_all_pool_stats(): {[string]: number}
    return {
        points = get_pool_stats(point_pool),
        batched_calls = get_pool_stats(batched_call_pool),
        polygons = get_pool_stats(polygon_pool),
        temp_arrays = get_pool_stats(temp_arrays_pool)
    }
end

MemoryPools.create_pool = create_pool
MemoryPools.get_from_pool = get_from_pool
MemoryPools.return_to_pool = return_to_pool
MemoryPools.get_pool_stats = get_pool_stats

MemoryPools.get_point = get_point
MemoryPools.return_point = return_point
MemoryPools.get_batched_call = get_batched_call
MemoryPools.return_batched_call = return_batched_call
MemoryPools.get_polygon = get_polygon
MemoryPools.return_polygon = return_polygon
MemoryPools.get_temp_array = get_temp_array
MemoryPools.return_temp_array = return_temp_array
MemoryPools.get_all_pool_stats = get_all_pool_stats

return MemoryPools