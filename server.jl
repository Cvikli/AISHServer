using Revise
using RelevanceStacktrace
using HTTP
using Dates
using JSON: json, parse
using Sockets

using AISH: initialize_ai_state, set_project_path, update_system_prompt!,
  select_conversation, generate_new_conversation,
  process_query, AIState, conversation_to_dict, system_prompt, streaming_process_query,
  cur_conv_msgs, update_message_with_outputs, add_n_save_ai_message!

handle_interrupt(sig::Int32) = (println("\nExiting gracefully. Good bye! :)"); exit(0))
ccall(:signal, Ptr{Cvoid}, (Cint, Ptr{Cvoid}), 2, @cfunction(handle_interrupt, Cvoid, (Int32,)))

const ROUTER = HTTP.Router()
const ROUTER_Stream = HTTP.Router()

global ai_state::AIState = initialize_ai_state() # = AIState()

const AI_STATE_NOT_INITIALIZED_ERROR = Dict("status" => "error", "message" => "AI state not initialized")


HTTP.serve!(ROUTER, "0.0.0.0", 8001)
HTTP.serve!(ROUTER_Stream, "0.0.0.0", 8002; stream=true)

entr(["APIEndpoints.jl", "APIEndpointsStream.jl"], [], postpone=true, pause=1.00) do
  include("APIEndpoints.jl")
  include("APIEndpointsStream.jl")
end
