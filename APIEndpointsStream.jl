
HTTP.register!(ROUTER_Stream, "POST", "/stream/process_message", function(stream::HTTP.Stream) 
  data = parse(String(read(stream)))
  user_message = get(data, "new_message", "")
  @show user_message


  channel, user_meta, ai_meta, start_time, user_msg = streaming_process_question(ai_state, user_message)

  write(stream, "event: start\ndata: $(json(Dict("content" => "Stream started")))\n\n")
  flush(stream)

  write(stream, "event: ping\ndata: $(round(Int, time()))\n\n")
  flush(stream)


  first_text = take!(channel)
  whole_txt = first_text

  user_meta.elapsed -= start_time
  update_last_user_message_meta(ai_state, user_meta)
  user_data = to_dict(user_meta)
  user_data[:timestamp] = date_format(user_msg.timestamp)
  # @show user_data
  write(stream, "event: user_meta\ndata: $(json(user_data))\n\n")
  flush(stream)

  write(stream, "event: message\ndata: $(json(Dict("content" => first_text)))\n\n")
  flush(stream)

  for text in channel
    whole_txt *= text
    write(stream, "event: message\ndata: $(json(Dict("content" => text)))\n\n")
    flush(stream)
  end
  
  ai_meta.elapsed = ai_meta.elapsed - start_time - user_meta.elapsed
  
  updated_content = ai_state.skip_code_execution ? whole_txt : update_message_with_outputs(whole_txt)
  ai_msg = add_n_save_ai_message!(ai_state, updated_content, ai_meta)
  ai_data = to_dict(ai_meta)
  ai_data[:timestamp] = date_format(ai_msg.timestamp)
  # @show ai_data

  write(stream, "event: ai_meta\ndata: $(json(ai_data))\n\n")
  flush(stream)
  write(stream, "event: done\ndata: $(json(Dict("content" => updated_content)))\n\n")
  flush(stream)
  println("$(updated_content)")
  return nothing
end)
