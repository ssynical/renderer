--!strict
--!native
--!optimize 2

local Types = require("types")
local MemoryPools = require("memorypools")

type BatchedCall = Types.BatchedCall
type Color = Types.Color

local batch = {}

local function create_batch_system(max_batch_size: number): {BatchedCall}
    return {}
end

local function add_to_batch(batch: {BatchedCall}, call_type: string, color: Color, data: any, alpha: number?)
    local call = MemoryPools.get_batched_call()
    call.type = call_type
    call.color = color
    call.data = data
    call.alpha = alpha
    
    table.insert(batch, call)
end

local function can_batch_together(call1: BatchedCall, call2: BatchedCall): boolean
    return call1.type == call2.type and 
           call1.color == call2.color and 
           call1.alpha == call2.alpha
end

local function optimize_batch(batch: {BatchedCall}): {BatchedCall}
    if #batch <= 1 then
        return batch
    end
    
    local optimized = MemoryPools.get_temp_array()
    local current_group = MemoryPools.get_temp_array()
    
    table.insert(current_group, batch[1])
    
    for i = 2, #batch do
        local current_call = batch[i]
        local last_in_group = current_group[#current_group]
        
        if can_batch_together(current_call, last_in_group) then
            table.insert(current_group, current_call)
        else
            if #current_group > 1 then
                local merged_call = MemoryPools.get_batched_call()
                merged_call.type = "batched_" .. last_in_group.type
                merged_call.color = last_in_group.color
                merged_call.alpha = last_in_group.alpha
                merged_call.data = {unpack(current_group)}
                
                table.insert(optimized, merged_call)
                
                for _, call in ipairs(current_group) do
                    MemoryPools.return_batched_call(call)
                end
            else
                table.insert(optimized, current_group[1])
            end
            
            for j = #current_group, 1, -1 do
                current_group[j] = nil
            end
            table.insert(current_group, current_call)
        end
    end
    
    if #current_group > 1 then
        local merged_call = MemoryPools.get_batched_call()
        merged_call.type = "batched_" .. current_group[1].type
        merged_call.color = current_group[1].color
        merged_call.alpha = current_group[1].alpha
        merged_call.data = {unpack(current_group)}
        
        table.insert(optimized, merged_call)
        
        for _, call in ipairs(current_group) do
            MemoryPools.return_batched_call(call)
        end
    elseif #current_group == 1 then
        table.insert(optimized, current_group[1])
    end
    
    MemoryPools.return_temp_array(current_group)
    
    local result = {unpack(optimized)}
    MemoryPools.return_temp_array(optimized)
    
    return result
end

local function execute_batch(batch: {BatchedCall}, draw_pixel: (number, number, Color, number?) -> boolean, draw_line: (number, number, number, number, Color, number?, number?) -> ())
    local optimized_batch = optimize_batch(batch)
    
    for _, call in ipairs(optimized_batch) do
        if call.type == "pixel" then
            local data = call.data
            draw_pixel(data.x, data.y, call.color, call.alpha)
            
        elseif call.type == "line" then
            local data = call.data
            draw_line(data.x1, data.y1, data.x2, data.y2, call.color, data.width, call.alpha)
            
        elseif call.type == "batched_pixel" then
            for _, pixel_call in ipairs(call.data) do
                local data = pixel_call.data
                draw_pixel(data.x, data.y, call.color, call.alpha)
            end
            
        elseif call.type == "batched_line" then
            for _, line_call in ipairs(call.data) do
                local data = line_call.data
                draw_line(data.x1, data.y1, data.x2, data.y2, call.color, data.width, call.alpha)
            end
        end
        
        MemoryPools.return_batched_call(call)
    end
end

local function clear_batch(batch: {BatchedCall})
    for _, call in ipairs(batch) do
        MemoryPools.return_batched_call(call)
    end
    
    for i = #batch, 1, -1 do
        batch[i] = nil
    end
end

local function get_batch_stats(batch: {BatchedCall}): {total_calls: number, batchable_calls: number}
    local batchable = 0
    local last_call = nil
    
    for _, call in ipairs(batch) do
        if last_call and can_batch_together(call, last_call) then
            batchable = batchable + 1
        end
        last_call = call
    end
    
    return {
        total_calls = #batch,
        batchable_calls = batchable
    }
end

batch.create_batch_system = create_batch_system
batch.add_to_batch = add_to_batch
batch.optimize_batch = optimize_batch
batch.execute_batch = execute_batch
batch.clear_batch = clear_batch
batch.get_batch_stats = get_batch_stats

return batch