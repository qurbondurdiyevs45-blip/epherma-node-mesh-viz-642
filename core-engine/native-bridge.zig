const std = @import("std");

/// EphemeraNode Mesh Viz - Native Bridge
/// High-performance memory management and vertex buffer alignment for WebGL/WASM acceleration.
/// Optimized for transient failure heat-maps where vertex data is frequently invalidated.

pub const Vertex = struct {
    x: f32,
    y: f32,
    intensity: f32,
    timestamp: f32,
    status_code: u32,
};

pub const MeshHeader = struct {
    vertex_count: u32,
    capacity: u32,
    stride: u32,
    last_updated: i64,
};

pub const AllocatorError = error{
    OutOfMemory,
    InvalidAlignment,
    BufferOverflow,
};

const MAX_VERTICES = 1048576; // 1M vertices per slice for L3 cache optimization

pub const NativeBridge = struct {
    allocator: std.mem.Allocator,
    vertex_buffer: []Vertex,
    header: *MeshHeader,

    pub fn init(allocator: std.mem.Allocator, initial_capacity: u32) !NativeBridge {
        const cap = if (initial_capacity > MAX_VERTICES) MAX_VERTICES else initial_capacity;
        
        // Allocate header and buffer in a single contiguous block for cache locality
        const buffer = try allocator.alloc(Vertex, cap);
        const header = try allocator.create(MeshHeader);

        header.* = .{
            .vertex_count = 0,
            .capacity = cap,
            .stride = @sizeOf(Vertex),
            .last_updated = std.time.timestamp(),
        };

        return NativeBridge{
            .allocator = allocator,
            .vertex_buffer = buffer,
            .header = header,
        };
    }

    pub fn deinit(self: *NativeBridge) void {
        self.allocator.free(self.vertex_buffer);
        self.allocator.destroy(self.header);
    }

    /// Appends failure data point to the buffer. 
    /// If capacity is reached, it wraps around (Ring Buffer strategy for 24h window).
    pub fn pushVertex(self: *NativeBridge, x: f32, y: f32, intensity: f32, status: u32) void {
        const index = self.header.vertex_count % self.header.capacity;
        
        self.vertex_buffer[index] = .{
            .x = x,
            .y = y,
            .intensity = intensity,
            .timestamp = @as(f32, @floatFromInt(std.time.milliTimestamp())),
            .status_code = status,
        };

        self.header.vertex_count += 1;
        self.header.last_updated = std.time.timestamp();
    }

    /// Returns a raw pointer for WebGL consumption via WASM memory mapping.
    pub fn getRawBufferPointer(self: *NativeBridge) [*]const u8 {
        return @ptrCast(self.vertex_buffer.ptr);
    }

    /// Size in bytes for gl.bufferData
    pub fn getBufferSize(self: *NativeBridge) usize {
        const count = if (self.header.vertex_count > self.header.capacity) 
            self.header.capacity 
        else 
            self.header.vertex_count;
        return count * @sizeOf(Vertex);
    }

    /// Batch process decay for the heat-map to simulate "ephemeral" nature.
    pub fn applyDecay(self: *NativeBridge, decay_factor: f32) void {
        const count = if (self.header.vertex_count > self.header.capacity) 
            self.header.capacity 
        else 
            self.header.vertex_count;
            
        for (0..count) |i| {
            self.vertex_buffer[i].intensity *= decay_factor;
        }
    }
};

// Exported Symbols for WebAssembly linkage
export fn bridge_create(capacity: u32) ?*NativeBridge {
    const allocator = std.heap.page_allocator;
    const bridge = allocator.create(NativeBridge) catch return null;
    bridge.* = NativeBridge.init(allocator, capacity) catch return null;
    return bridge;
}

export fn bridge_push(instance: *NativeBridge, x: f32, y: f32, intensity: f32, status: u32) void {
    instance.pushVertex(x, y, intensity, status);
}

export fn bridge_get_ptr(instance: *NativeBridge) [*]const u8 {
    return instance.getRawBufferPointer();
}

export fn bridge_get_size(instance: *NativeBridge) usize {
    return instance.getBufferSize();
}

export fn bridge_decay(instance: *NativeBridge, factor: f32) void {
    instance.applyDecay(factor);
}