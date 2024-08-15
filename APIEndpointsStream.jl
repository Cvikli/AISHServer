
HTTP.register!(ROUTER_Stream, "POST", "/stream/process_message", function(stream::HTTP.Stream) 
  data = JSON.parse(String(read(stream)))
  user_message = get(data, "new_message", "")
  @show user_message


    write(stream, "event: start\ndata: Stream started\n\n")
    flush(stream)

    write(stream, "event: ping\ndata: $(round(Int, time()))\n\n")
    flush(stream)


    channel = streaming_process_query(ai_state, user_message)
    whole_txt = ""

    for text in channel
        whole_txt *= text
        write(stream, "event: message\ndata: $(JSON.json(Dict("content" => text)))\n\n")
        flush(stream)
    end
    
    updated_content = update_message_with_outputs(whole_txt)
    add_n_save_ai_message!(ai_state, updated_content)
    write(stream, "event: done\ndata: $(JSON.json(Dict("content" => updated_content)))\n\n")
    flush(stream)
    println("$(updated_content)")
    return nothing
end)
