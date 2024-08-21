using Revise
using RelevanceStacktrace
using HTTP
using Dates
using JSON
using JSON: json, parse
using Sockets
using Anthropic: to_dict

using AISH: initialize_ai_state, update_project_path_and_sysprompt!, 
  select_conversation, generate_new_conversation, cmd_all_info, curr_conv,
  process_question, AIState, to_dict_nosys_detailed, curr_conv_msgs, streaming_process_question,
   update_message_with_outputs, add_n_save_ai_message!, system_message, update_last_user_message_meta

handle_interrupt(sig::Int32) = (println("\nExiting gracefully. Good bye! :)"); exit(0))
ccall(:signal, Ptr{Cvoid}, (Cint, Ptr{Cvoid}), 2, @cfunction(handle_interrupt, Cvoid, (Int32,)))

global ai_state::AIState = initialize_ai_state(streaming=false, skip_code_execution=true) # = AIState()

const ROUTER = HTTP.Router()
const ROUTER_Stream = HTTP.Router()

include("CORS.jl")
include("APIEndpoints.jl")
include("APIEndpointsStream.jl")

HTTP.serve!(with_cors_stream(ROUTER_Stream), "0.0.0.0", 8002; stream=true)
HTTP.serve!(with_cors(ROUTER), "0.0.0.0", 8001)

entr(["APIEndpoints.jl", "APIEndpointsStream.jl"], [], postpone=true, pause=1.00) do
# entr(["APIEndpoints.jl"], [], postpone=true, pause=1.00) do
  include("APIEndpoints.jl")  
  include("APIEndpointsStream.jl")
end
