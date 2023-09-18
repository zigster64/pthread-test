const std = @import("std");

const Mode = enum {
    join,
    detach,
    waitgroup,
    pool,
};

pub fn main() !void {
    var mode: Mode = Mode.join;

    var thread_count: u32 = 16;
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();

    // parse cmdline args
    const args = try std.process.argsAlloc(allocator);
    errdefer std.process.argsFree(allocator, args);

    // create a thread pool if we need it for pool mode
    var thread_pool: std.Thread.Pool = undefined;

    if (args.len > 1) {
        if (std.mem.eql(u8, args[1], "--help")) {
            std.debug.print("pthread-test arguments:  -j (DEFAULT .. join threads), -d (detach threads), -p [N] (thread pool mode, with N threads, default 16)\n", .{});
            return;
        }
        if (std.mem.eql(u8, args[1], "-j")) {
            mode = Mode.join;
            std.debug.print("Thread join mode\n", .{});
        }
        if (std.mem.eql(u8, args[1], "-d")) {
            mode = Mode.detach;
            std.debug.print("Thread detached mode\n", .{});
        }
        if (std.mem.eql(u8, args[1], "-w")) {
            mode = Mode.waitgroup;
            std.debug.print("Thread detached mode with waitgroup\n", .{});
        }
        if (std.mem.eql(u8, args[1], "-p")) {
            mode = Mode.pool;
            if (args.len > 2) {
                thread_count = try std.fmt.parseInt(u32, args[2], 10);
            }
            try std.Thread.Pool.init(&thread_pool, .{ .allocator = allocator, .n_jobs = thread_count });
            std.debug.print("Thread pool with {} threads\n", .{thread_count});
        }
    } else {
        std.debug.print("Thread join mode\n", .{});
    }
    std.process.argsFree(allocator, args);

    var wg: std.Thread.WaitGroup = .{};
    var thread_id: usize = 0;

    while (true) {
        thread_id += 1;

        switch (mode) {
            Mode.join => {
                // wait for the thread to exit, and the ruasge remains constant over time
                // after join, can immediately spawn the next thread
                const t = std.Thread.spawn(.{}, thread_function, .{ thread_id, mode }) catch |err| {
                    std.debug.print("Join Spawn {}\n", .{err});
                    std.time.sleep(std.time.ns_per_min);
                    return err;
                };
                t.join();
            },
            Mode.waitgroup => {
                wg.start();
                const t = std.Thread.spawn(.{}, thread_waitgroup_function, .{ thread_id, &wg }) catch |err| {
                    std.debug.print("Wait Spawn {}\n", .{err});
                    std.time.sleep(std.time.ns_per_min);
                    return err;
                };
                t.detach();
                wg.wait();
                wg.reset();
            },
            Mode.detach => {
                const t = std.Thread.spawn(.{}, thread_function, .{ thread_id, mode }) catch |err| {
                    std.debug.print("Detach Spawn {}\n", .{err});
                    std.time.sleep(std.time.ns_per_min);
                    return err;
                };
                t.detach();
                std.time.sleep(std.time.ns_per_ms);
                if (thread_id % 5_000 == 0) {
                    std.debug.print("Catch breath ...\n", .{});
                    std.time.sleep(std.time.ns_per_s * 3);
                }
            },
            Mode.pool => {
                thread_pool.spawn(thread_function, .{ thread_id, mode }) catch |err| {
                    std.debug.print("Pool Spawn {}\n", .{err});
                    std.time.sleep(std.time.ns_per_min);
                    return err;
                };
                std.time.sleep(std.time.ns_per_ms);
            },
        }
    }
}

fn thread_function(id: usize, mode: Mode) void {
    const r = std.os.getrusage(0);
    std.debug.print("Spawn a new thread {} mode {s} maxrss = {}\n", .{ id, @tagName(mode), r.maxrss });
    std.time.sleep(std.time.ns_per_ms);
}

fn thread_waitgroup_function(id: usize, wg: *std.Thread.WaitGroup) void {
    const r = std.os.getrusage(0);
    std.debug.print("Spawn a new thread {} mode Waitgroup maxrss = {}\n", .{ id, r.maxrss });
    std.time.sleep(std.time.ns_per_ms);
    wg.finish();
}
