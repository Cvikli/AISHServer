using Genie
using Genie.Router
using Genie.Requests
using Genie.Renderer.Json
using HTTP
using Dates
using JSON: json

using AISH: initialize_ai_state, set_project_path, update_system_prompt!,
select_conversation, generate_new_conversation,
process_query, AIState, conversation_to_dict, system_prompt

global ai_state::AIState = AIState()

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
# route("/api/conversation_history", method = GET) do
#   !is_ai_state_initialized() && return json(AI_STATE_NOT_INITIALIZED_ERROR)
#   json(Dict("status" => "success", "history" => conversation_to_dict(ai_state)))
# end

up(8001, "0.0.0.0", async = false)
