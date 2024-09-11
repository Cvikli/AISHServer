HTTP.register!(ROUTER_Stream, "POST", "/stream/process_message", function(stream::HTTP.Stream) 
    try
        data = parse(String(read(stream)))
        user_message = get(data, "new_message", "")
        shell_results = get(data, "shell_results", Dict{String, String}())

        channel, user_msg, e = streaming_process_question(ai_state, user_message, shell_results)
        if !isnothing(e)
            error_message = "Error in streaming process: $(sprint(showerror, e))"
            write(stream, "event: error\ndata: $(json(Dict("content" => error_message)))\n\n")
            flush(stream)
            return
        end

        write(stream, "event: start\ndata: $(json(Dict("content" => "Stream started")))\n\n")
        write(stream, "event: ping\ndata: $(round(Int, time()))\n\n")
        flush(stream)

        start_time = time()

        full_response, user_meta, ai_meta = process_stream(
            channel,
            ai_state.model,
            on_text = function(text)
                print(text)
                write(stream, "event: message\ndata: $(json(Dict("content" => text)))\n\n")
                flush(stream)
            end,
            on_meta_usr = function(meta)
                update_last_user_message_meta(ai_state, meta)
                user_data = merge(meta, Dict(
                    "id" => user_msg.id,
                    "timestamp" => date_format(user_msg.timestamp)
                    ))
                write(stream, "event: user_meta\ndata: $(json(user_data))\n\n")
                flush(stream)
            end,
            on_error = function(error)
                write(stream, "event: error\ndata: $(json(Dict("content" => error)))\n\n")
                flush(stream)
            end,
            on_done = function()
                println()
            end
        )
        ai_msg = add_n_save_ai_message!(ai_state, full_response, ai_meta)
        ai_data = merge(ai_meta, Dict("timestamp" => date_format(ai_msg.timestamp)))
        write(stream, "event: ai_meta\ndata: $(json(ai_data))\n\n")
        flush(stream)
        # write(stream, "event: done\ndata: $(json(Dict("content" => full_response)))\n\n")
        write(stream, "event: done\ndata: $(json(Dict("content" => "")))\n\n")
        flush(stream)
    catch e
        error_message = "Error in streaming process: $(sprint(showerror, e))"
        @error error_message exception=(e, catch_backtrace())
        write(stream, "event: error\ndata: $(json(Dict("content" => error_message)))\n\n")
        flush(stream)
    end

    return
end)

HTTP.register!(ROUTER_Stream, "POST", "/stream/execute_shell", function(stream::HTTP.Stream)
    try
        data = parse(String(read(stream)))
        command = get(data, "command", "")

        channel = Channel(32)
        task = @async begin
            try
                execute_shell_command_async(command, channel)
            finally
                close(channel)
            end
        end

        write(stream, "event: start\ndata: $(json(Dict("content" => "Shell execution started")))\n\n")
        flush(stream)

        for output in channel
            write(stream, "event: output\ndata: $(json(Dict("content" => output)))\n\n")
            flush(stream)
        end

        write(stream, "event: done\ndata: $(json(Dict("content" => "Shell execution finished")))\n\n")
        flush(stream)
    catch e
        error_message = "Error in shell execution: $(sprint(showerror, e))"
        @error error_message exception=(e, catch_backtrace())
        write(stream, "event: error\ndata: $(json(Dict("content" => error_message)))\n\n")
        flush(stream)
    finally
        close(stream)
    end

    return
end)

HTTP.register!(ROUTER_Stream, "POST", "/stream/select_folder", function(stream::HTTP.Stream)
    try
        data = parse(String(read(stream)))
        path = get(data, "path", "")

        channel = Channel(32)
        task = @async begin
            try
                select_folder_async(path, channel)
            finally
                close(channel)
            end
        end

        write(stream, "event: start\ndata: $(json(Dict("content" => "Folder selection started")))\n\n")
        flush(stream)

        for item in channel
            write(stream, "event: item\ndata: $(json(Dict("content" => item)))\n\n")
            flush(stream)
        end

        write(stream, "event: done\ndata: $(json(Dict("content" => "Folder selection finished")))\n\n")
        flush(stream)
    catch e
        error_message = "Error in folder selection: $(sprint(showerror, e))"
        @error error_message exception=(e, catch_backtrace())
        write(stream, "event: error\ndata: $(json(Dict("content" => error_message)))\n\n")
        flush(stream)
    finally
        close(stream)
    end

    return
end)

HTTP.register!(ROUTER_Stream, "POST", "/stream/modify_file", function(stream::HTTP.Stream)
    try
        data = parse(String(read(stream)))
        file_path = get(data, "file_path", "")
        modifications = get(data, "modifications", "")

        channel = Channel(32)
        task = @async begin
            try
                modify_file_async(file_path, modifications, channel)
            finally
                close(channel)
            end
        end
        write(stream, "event: start\ndata: $(json(Dict("content" => "File modification started")))\n\n")
        flush(stream)

        for update in channel
            write(stream, "event: update\ndata: $(json(Dict("content" => update)))\n\n")
            flush(stream)
        end

        write(stream, "event: done\ndata: $(json(Dict("content" => "File modification finished")))\n\n")
        flush(stream)
    catch e
        error_message = "Error in file modification: $(sprint(showerror, e))"
        @error error_message exception=(e, catch_backtrace())
        write(stream, "event:error\ndata: $(json(Dict("content" => error_message)))\n\n")
        flush(stream)
    finally
        close(stream)
    end
    return
end)
