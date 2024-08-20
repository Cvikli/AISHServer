
HTTP.register!(ROUTER_Stream, "POST", "/stream/process_message", function(stream::HTTP.Stream) 
  data = JSON.parse(String(read(stream)))
  user_message = get(data, "new_message", "")
  @show user_message


  channel, user_meta, ai_meta, start_time = streaming_process_query(ai_state, user_message)

  write(stream, "event: start\ndata: $(JSON.json(Dict("content" => "Stream started")))\n\n")
  flush(stream)

  write(stream, "event: ping\ndata: $(round(Int, time()))\n\n")
  flush(stream)


  first_text = take!(channel)
  whole_txt = first_text

  user_meta.elapsed -= start_time
  @show to_dict(user_meta)
  write(stream, "event: user_meta\ndata: $(JSON.json(to_dict(user_meta)))\n\n")
  flush(stream)

  write(stream, "event: message\ndata: $(JSON.json(Dict("content" => first_text)))\n\n")
  flush(stream)

  for text in channel
    whole_txt *= text
    write(stream, "event: message\ndata: $(JSON.json(Dict("content" => text)))\n\n")
    flush(stream)
  end
  
  updated_content = update_message_with_outputs(whole_txt)
  add_n_save_ai_message!(ai_state, updated_content)
  ai_meta.elapsed = ai_meta.elapsed - start_time - user_meta.elapsed
  @show to_dict(ai_meta)
  write(stream, "event: ai_meta\ndata: $(JSON.json(to_dict(ai_meta)))\n\n")
  flush(stream)
  write(stream, "event: done\ndata: $(JSON.json(Dict("content" => updated_content)))\n\n")
  flush(stream)
  println("$(updated_content)")
  return nothing
end)
