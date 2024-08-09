using Genie
using Genie.Router
using Genie.Requests
using Genie.Renderer.Json
using HTTP
using Dates
using JSON: json

using AISH: initialize_ai_state, set_project_path, update_system_prompt!,
select_conversation, generate_new_conversation,
process_query, AIState, conversation_to_dict, system_prompt, streaming_process_query,
cur_conv_msgs, update_message_with_outputs, add_n_save_ai_message!

global ai_state::AIState = initialize_ai_state() # = AIState()

const AI_STATE_NOT_INITIALIZED_ERROR = Dict("status" => "error", "message" => "AI state not initialized")

handle_interrupt(sig::Int32) = (println("\nExiting gracefully. Good bye! :)"); exit(0))
ccall(:signal, Ptr{Cvoid}, (Cint, Ptr{Cvoid}), 2, @cfunction(handle_interrupt, Cvoid, (Int32,)))

is_ai_state_initialized() = !isnothing(ai_state)

# Configure CORS
Genie.config.cors_headers["Access-Control-Allow-Origin"] = "*"
Genie.config.cors_headers["Access-Control-Allow-Headers"] = "Content-Type"
Genie.config.cors_headers["Access-Control-Allow-Methods"] = "GET,POST,PUT,DELETE,OPTIONS"

Genie.config.run_as_server = true

# API routes
route("/api/initialize", method = GET) do 
  global ai_state = initialize_ai_state()
  json(Dict(
      "status" => "success",
      "message" => "AI state initialized",
      "system_prompt" => system_prompt(ai_state).content,
      "conversation_id" => ai_state.selected_conv_id,
      "available_conversations" =>  ai_state.conversation,
  ))
end

route("/api/set_path", method = POST) do 
  path = jsonpayload()["path"]
  isempty(path) && return json(Dict("status" => "error", "message" => "Path not provided"))
  set_project_path(path)
  json(Dict("status" => "success", "message" => "Project path set to "))
end

route("/api/update_system_prompt", method = POST) do 
  !is_ai_state_initialized() && return json(AI_STATE_NOT_INITIALIZED_ERROR)
  update_system_prompt!(ai_state, new_system_prompt=jsonpayload()["conversation_id"])
  json(Dict("status" => "success", "message" => "System prompt updated"))
end

route("/api/refresh_project", method = GET) do 
  !is_ai_state_initialized() && return json(AI_STATE_NOT_INITIALIZED_ERROR)
  update_system_prompt!(ai_state)
  json(Dict("status" => "success", "message" => "System prompt refreshed"))
end

route("/api/new_conversation", method = POST) do 
  !is_ai_state_initialized() && return json(AI_STATE_NOT_INITIALIZED_ERROR)
  new_id = generate_new_conversation(ai_state)
  json(Dict("status" => "success", "message" => "New conversation started", "conversation_id" => new_id))
end
route("/api/select_conversation", method = POST) do 
  !is_ai_state_initialized() && return json(AI_STATE_NOT_INITIALIZED_ERROR)
  
  conversation_id = jsonpayload()["conversation_id"]
  @show conversation_id
  isempty(conversation_id) && return json(Dict("status" => "error", "message" => "Conversation ID not provided"))
  !haskey(ai_state.conversation, conversation_id) && return json(Dict("status" => "error", "message" => "Conversation not found"))
  (ai_state.selected_conv_id !== conversation_id) && select_conversation(ai_state, conversation_id)
  json(Dict("status" => "success", "message" => "Conversation selected and loaded", "history" => conversation_to_dict(ai_state)))
end

route("/api/process_message", method = POST) do 
  !is_ai_state_initialized() && return json(AI_STATE_NOT_INITIALIZED_ERROR)
  
  user_message = jsonpayload()["message"]
  msg = process_query(ai_state, user_message)    

  json(Dict("status" => "success", "response" => msg.content, 
            "timestamp" => Dates.format(msg.timestamp, "yyyy-mm-dd_HH:MM:SS"), 
            "conversation_id" => ai_state.selected_conv_id))
end
channel("/stream/process_message") do
  params = jsonpayload()
  @show params
  try
    user_message = params["new_message"]
    @show user_message
    Genie.Renderer.streamresponse() do io
      channel = streaming_process_query(ai_state, user_message)
      @show "channel??"
      for text in channel
        @show "yes-yes!"
        write(io, "data: $text\n\n")
        flush(io)
      end
      @show "done!"
      write(io, "data: [DONE]\n\n")
      write(io, "all:  $(ai_state.conversation[end].content)")
      flush(io)
    end
  catch e
    Json.json(:error => sprint(showerror, e))
  end
end
# Genie.Router.channel("/stream/process_message") do ws
#   @show "?"
#   while !eof(ws)
#     data = JSON.parse(String(WebSockets.receive(ws)))
#     @show data
#     user_message = get(data, "new_message", "")
#     @show user_message
        
#         if !is_ai_state_initialized()
#             WebSockets.send(ws, json(AI_STATE_NOT_INITIALIZED_ERROR))
#             continue
#         end
        
#         channel = streaming_process_query(ai_state, user_message)
#         for text in channel
#           @show text
#             WebSockets.send(ws, "data: $text")
#         end
#         WebSockets.send(ws, "data: [DONE]")
#         WebSockets.send(ws, "all: $(ai_state.conversation[ai_state.selected_conv_id][end].content)")
#     end
# end

using HTTP, Sockets, JSON

const ROUTER = HTTP.Router()

function events(stream::HTTP.Stream)
  data = JSON.parse(String(readavailable(stream)))
  @show data
  user_message = get(data, "new_message", "")
  @show user_message

  HTTP.setheader(stream, "Access-Control-Allow-Origin" => "*")
  HTTP.setheader(stream, "Access-Control-Allow-Methods" => "GET,POST,PUT,DELETE,OPTIONS")
  HTTP.setheader(stream, "Content-Type" => "text/event-stream")

  if HTTP.method(stream.message) == "OPTIONS"
      return nothing
  end

  HTTP.setheader(stream, "Content-Type" => "text/event-stream")
  HTTP.setheader(stream, "Cache-Control" => "no-cache")

  write(stream, "event: ping\ndata: $(round(Int, time()))\n\n")

  # channel = stream_anthropic_response("Hello, tell me a short story")
  channel = streaming_process_query(ai_state, user_message)
  @show channel
  whole_txt = ""
  for text in channel
    whole_txt *= text
    write(stream, text)
    @show text
  end
  write(stream, "---------[DONE]-------")
  updated_content = update_message_with_outputs(whole_txt)
  add_n_save_ai_message!(ai_state, updated_content)
  write(stream, "all: $(updated_content)")
  @show "Finished"
  # write(stream, "all: $(cur_conv_msgs(ai_state)[end].content)")
  return nothing
end
HTTP.register!(ROUTER, "/stream/process_message", events)


server = HTTP.serve!(ROUTER, "127.0.0.1", 8080; stream=true)

# route("/api/conversation_history", method = GET) do
#   !is_ai_state_initialized() && return json(AI_STATE_NOT_INITIALIZED_ERROR)
#   json(Dict("status" => "success", "history" => conversation_to_dict(ai_state)))
# end

up(8001, "0.0.0.0", async = false)
