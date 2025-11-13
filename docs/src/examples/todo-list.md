# Todo List

A more complex example that showcases strings, slices, and error handling.

## Zig Types

```zig
const std = @import("std");

pub const Todo = extern struct {
    title: [64]u8,
    completed: bool,
};

pub const TodoList = extern struct {
    allocator: std.mem.Allocator,
    items: std.ArrayList(Todo),

    pub fn init(allocator: std.mem.Allocator) !TodoList {
        return .{ .allocator = allocator, .items = std.ArrayList(Todo).init(allocator) };
    }

    pub fn add(self: *TodoList, title: []const u8) !void {
        if (title.len == 0) return error.EmptyTitle;
        var todo = Todo{ .title = [_]u8{0} ** 64, .completed = false };
        const len = @min(title.len, todo.title.len);
        std.mem.copyForwards(u8, todo.title[0..len], title[0..len]);
        try self.items.append(todo);
    }

    pub fn toggle(self: *TodoList, index: usize) !void {
        if (index >= self.items.items.len) return error.OutOfRange;
        self.items.items[index].completed = !self.items.items[index].completed;
    }

    pub fn all(self: *TodoList) []const Todo {
        return self.items.items;
    }

    pub fn deinit(self: *TodoList) void {
        self.items.deinit();
    }
};
```

## TypeScript Interaction

```ts
const wasm = await loadWasm('todo.wasm');
const list = new TodoList(wasm);
await list.add('Write docs');
await list.add('Ship build');

const todos = list.all();
render(todos); // Typed array view with structs serialized as bytes (see generated interface)
```

## Lessons

- String parameters show marshaling helpers.
- Slice returns demonstrate `_ptr` / `_len` pattern.
- Errors propagate as exceptions (`EmptyTitle`, `OutOfRange`).
- `deinit` frees Zig-side `ArrayList` memory when the TypeScript instance calls `.destroy()`.
