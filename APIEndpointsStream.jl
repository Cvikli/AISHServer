HTTP.register!(ROUTER_Stream, "POST", "/stream/process_message", function(stream::HTTP.Stream) 
    try
        data = parse(String(read(stream)))
        user_message = get(data, "new_message", "")
        shell_results = Dict{String, CodeBlock}()

        user_msg = prepare_user_message!(ai_state.contexter, ai_state, user_question, shell_results)
        add_n_save_user_message!(ai_state, user_msg)

        channel, shell_scripts, e = streaming_process_question(ai_state,
            on_start = sonstart() = begin
                write(stream, "event: start\ndata: $(json(Dict("content" => "Stream started")))\n\n")
                write(stream, "event: ping\ndata: $(round(Int, time()))\n\n")
                flush(stream)
            end,            
            on_text = sontext(text, cb) = begin
                write(stream, "event: message\ndata: $(json(Dict("content" => text)))\n\n")
                flush(stream)
                cb !== nothing && (write(stream, "event: codeblock\ndata: $(json(to_dict(cb)))\n\n"); flush(stream))
            end,
            on_meta_usr = sonmetausr(usr_msg) = begin
                write(stream, "event: user_meta\ndata: $(json(to_dict(usr_msg)))\n\n")
                flush(stream)
            end,
            on_meta_ai = sonmetaai(ai_msg) = begin
                write(stream, "event: ai_meta\ndata: $(json(to_dict(ai_msg)))\n\n")
                flush(stream)
            end,
            on_error = sonerror(error) = begin
                write(stream, "event: error\ndata: $(json(Dict("content" => error)))\n\n")
                flush(stream)
            end,
            on_done = sondone() = begin
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


