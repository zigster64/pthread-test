pthread-test

Run lots of threads in either:

- Join mode : spawn a thread then join it, as fast as possible 
- Detach mode: spawn a thread and detach it. Wait 1ms then do it again. (assume 1ms is ample time for the thread to execute and exit) 
- Pool mode: spawn a thread as part of a thread pool.

In each case, print the thread sequence id, and the current MAXRSS resource usage

Note that 

- Join:  does not appear to grow memory over time 
- Detach: appears to grow memory over time 
- Pool: appears to not grow memory over time

Could be that there is a bug in zig stdlib implementation of thread.spawn() ? mostly cleaning up correctly, but not always ?
Or ... it could be just that the OS implementation is fragmententing memory over time  ?  not sure
