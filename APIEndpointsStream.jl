
HTTP.register!(ROUTER_Stream, "POST", "/stream/process_message", function(req::HTTP.Request) 
  stream = HTTP.stream(req)
  @show stream
  data = JSON.parse(String(read(stream)))
  @show data
  user_message = get(data, "new_message", "")
  @show user_message

  HTTP.setheader(req, "Access-Control-Allow-Origin" => "*")
  HTTP.setheader(req, "Access-Control-Allow-Methods" => "GET,POST,PUT,DELETE,OPTIONS")
  HTTP.setheader(req, "Content-Type" => "text/event-stream")
  HTTP.setheader(req, "Cache-Control" => "no-cache")

  HTTP.method(stream.message) == "OPTIONS" && return nothing


  write(stream, "event: ping\ndata: $(round(Int, time()))\n\n")

  # channel = stream_anthropic_response("Hello, tell me a short story")
  channel = streaming_process_query(ai_state, user_message)
  @show channel
  whole_txt = ""
  for text in channel
    whole_txt *= text
    write(stream, text)
  end
  write(stream, "---------[DONE]-------")
  updated_content = update_message_with_outputs(whole_txt)
  write(stream, "all: $(updated_content)")
  add_n_save_ai_message!(ai_state, updated_content)
  @show "Finished"
  # write(stream, "all: $(cur_conv_msgs(ai_state)[end].content)")
  return nothing
end)
