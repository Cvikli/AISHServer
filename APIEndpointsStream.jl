HTTP.register!(ROUTER_Stream, "POST", "/stream/process_message", function(stream::HTTP.Stream) 
    try
        data = parse(String(read(stream)))
        user_message = get(data, "new_message", "")
        shell_results = Dict{String, CodeBlock}()

        channel, user_msg, e = streaming_process_question(ai_state, user_message, shell_results,
            on_start = function()
                write(stream, "event: start\ndata: $(json(Dict("content" => "Stream started")))\n\n")
                write(stream, "event: ping\ndata: $(round(Int, time()))\n\n")
                flush(stream)
            end,            
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
            on_meta_ai = function(meta, full_response)
                ai_msg = add_n_save_ai_message!(ai_state, full_response, ai_meta)
                ai_data = merge(ai_meta, Dict("timestamp" => date_format(ai_msg.timestamp)))
                write(stream, "event: ai_meta\ndata: $(json(ai_data))\n\n")
                flush(stream)
            end,
            on_error = function(error)
                write(stream, "event: error\ndata: $(json(Dict("content" => error)))\n\n")
                flush(stream)
            end,
            on_done = function()
                # write(stream, "event: done\ndata: $(json(Dict("content" => "")))\n\n")
                # flush(stream)
                println()
            end
        )
        if !isnothing(e)
            error_message = "Error in streaming process: $(sprint(showerror, e))"
            write(stream, "event: error\ndata: $(json(Dict("content" => error_message)))\n\n")
            flush(stream)
            return
        end

        # write(stream, "event: done\ndata: $(json(Dict("content" => full_response)))\n\n")
    catch e
        error_message = "Error in streaming process: $(sprint(showerror, e))"
        @error error_message exception=(e, catch_backtrace())
        write(stream, "event: error\ndata: $(json(Dict("content" => error_message)))\n\n")
        flush(stream)
    end

    return
end)


