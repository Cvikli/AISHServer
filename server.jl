using Revise
using RelevanceStacktrace
using HTTP
using Dates
using JSON: json, parse
using Anthropic: to_dict, process_stream
using EasyContext: EasyContextCreatorV3
using DiffLib: diff_contents  # Add this line to import diff_files

using BoilerplateCvikli: @async_showerr


handle_interrupt(sig::Int32) = (println("\nExiting gracefully. Good bye! :)"); exit(0))
ccall(:signal, Ptr{Cvoid}, (Cint, Ptr{Cvoid}), 2, @cfunction(handle_interrupt, Cvoid, (Int32,)))
ccall(:signal, Ptr{Cvoid}, (Cint, Ptr{Cvoid}), 15, @cfunction(handle_interrupt, Cvoid, (Int32,)))


using AISH: initialize_ai_state, update_project_path_and_sysprompt!, 
select_conversation, generate_new_conversation, execute_single_shell_command, curr_conv,
AIState, to_dict_nosys_detailed, curr_conv_msgs, streaming_process_question,
add_n_save_ai_message!, system_message, 
update_last_user_message_meta, get_message_by_id, update_message_by_idx, date_format, curr_proj_path,
generate_ai_command_from_meld_code, save_file

global ai_state::AIState = initialize_ai_state("claude-3-5-sonnet-20240620", no_confirm=true)#, contexter=EasyContextCreatorV3())

const ROUTER = HTTP.Router()
const ROUTER_Stream = HTTP.Router()

include("CORS.jl")
include("APIEndpoints.jl")
include("APIEndpointsStream.jl")

HTTP.serve!(with_cors_stream(ROUTER_Stream), "0.0.0.0", 8002; stream=true)
HTTP.serve!(with_cors(ROUTER), "0.0.0.0", 8001)

entr(["APIEndpoints.jl", "APIEndpointsStream.jl"], [], postpone=true, pause=2.00) do
  include("APIEndpoints.jl")  
  include("APIEndpointsStream.jl")
end
