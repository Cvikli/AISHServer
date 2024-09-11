using Base.Threads

mutable struct TaskManager
    tasks::Dict{String, Task}
    channels::Dict{String, Channel}
    lock::ReentrantLock

    TaskManager() = new(Dict{String, Task}(), Dict{String, Channel}(), ReentrantLock())
end

function add_task!(tm::TaskManager, id::String, task::Task, channel::Channel)
    lock(tm.lock) do
        tm.tasks[id] = task
        tm.channels[id] = channel
    end
end

function remove_task!(tm::TaskManager, id::String)
    lock(tm.lock) do
        delete!(tm.tasks, id)
        delete!(tm.channels, id)
    end
end

function get_channel(tm::TaskManager, id::String)
    lock(tm.lock) do
        get(tm.channels, id, nothing)
    end
end

function execute_async(tm::TaskManager, id::String, func::Function)
    channel = Channel(32)
    task = @async_showerr begin
        try
            func(channel)
        finally
            remove_task!(tm, id)
            close(channel)
        end
    end
    add_task!(tm, id, task, channel)
    return channel
end
