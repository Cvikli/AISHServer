HTTP.register!(ROUTER, "GET", "/api/initialize", req -> begin
@show ai_state.conversations[ai_state.selected_conv_id]
    
OK(
    "AI state initialized",
    Dict(
        "skip_code_execution" => ai_state.skip_code_execution,
        "model" => ai_state.model,
        "conversation_id" => ai_state.selected_conv_id,
        "system_prompt" => system_message(ai_state),
        "project_path" => curr_proj_path(ai_state),
        "available_conversations" => ai_state.conversations,
    )
)
end)

HTTP.register!(ROUTER, "POST", "/api/set_path", req -> begin
    data = parse(String(req.body))
    path = get(data, "path", "")
    isempty(path) && return ERROR(400, "Path not provided")
    update_project_path_and_sysprompt!(ai_state, [path])
    OK("Project path set", Dict("system_prompt" => system_message(ai_state)))
end)

HTTP.register!(ROUTER, "POST", "/api/new_conversation", req -> begin
    conversation = generate_new_conversation(ai_state)
    OK("New conversation started", Dict("system_prompt" => system_message(ai_state), "conversation" => conversation,
    "project_path" => curr_proj_path(ai_state)
    ))
end)

HTTP.register!(ROUTER, "POST", "/api/select_conversation", req -> begin
    data = parse(String(req.body))
    conversation_id = get(data, "conversation_id", "")
    isempty(conversation_id) && return ERROR(400, "Conversation ID not provided")
    !haskey(ai_state.conversations, conversation_id) && return ERROR(404, "Conversation not found")
    ai_state.selected_conv_id !== conversation_id && select_conversation(ai_state, conversation_id)
    OK("Conversation selected and loaded", Dict(
        "history" => to_dict_nosys_detailed(ai_state),
        "system_prompt" => system_message(ai_state)))
end)

HTTP.register!(ROUTER, "POST", "/api/process_message", req -> begin
    try
        data = parse(String(req.body))
        msg = process_question(ai_state, get(data, "message", ""))
        OK("Message processed", Dict(
            "timestamp" => date_format(msg.timestamp),
            "conversation_id" => ai_state.selected_conv_id,
            "response" => msg.content,
        ))
    catch e
        error_message = "Error processing message: $(sprint(showerror, e))"
        @error error_message exception=(e, catch_backtrace())
        ERROR(500, error_message)
    end
end)

HTTP.register!(ROUTER, "POST", "/api/list_items", req -> begin
    data = parse(String(req.body))
    path = get(data, "path", "")   
    @show path
    project_path = isempty(path) ? isempty(curr_conv(ai_state).rel_project_paths) ? pwd() : curr_proj_path(ai_state) : path
    @show project_path
    OK("Items listed", Dict(
        "project_path" => project_path,
        "folders" => [item for item in readdir(project_path) if isdir(joinpath(project_path, item))],
        "files" => [item for item in readdir(project_path) if isfile(joinpath(project_path, item))]
    ))
end)

HTTP.register!(ROUTER, "POST", "/api/execute_block", req -> begin
    try
        data = parse(String(req.body))
        code, timestamp = get(data, "code", ""), get(data, "timestamp", nothing)
        (isempty(code) || isnothing(timestamp)) && return ERROR(400, "Code block or timestamp not provided")
        
        result = execute_single_shell_command(code)
        idx, message = get_message_by_timestamp(ai_state, timestamp)
        isnothing(message) && return ERROR(404, "Message with given timestamp not found")
        updated_content = replace(message.content, "```sh\n$code```" => "```sh\n$code```\n```sh_run_results\n$result\n```")
        updated_content = replace(updated_content, r"(```sh_run_results\n.*?```)((\s*```sh_run_results\n.*?```)*)"s => s"\1")
        update_message_by_idx(ai_state, idx, updated_content)
        
        OK("Code block executed successfully", Dict("result" => result, "updated_content" => updated_content))
    catch e
        error_message = "Error executing code block: $(sprint(showerror, e))"
        @error error_message exception=(e, catch_backtrace())
        ERROR(500, error_message)
    end
end)

HTTP.register!(ROUTER, "POST", "/api/toggle_auto_execute", req -> begin
    ai_state.skip_code_execution = !ai_state.skip_code_execution
    OK("Auto-execute toggled", Dict("skip_code_execution" => ai_state.skip_code_execution))
end)

OK(data::Dict) = HTTP.Response(200, json(Dict("status" => "success", "message" => "", data...)))
OK(message::String, data::Dict) = HTTP.Response(200, json(Dict("status" => "success", "message" => message, data...)))
ERROR(code::Int, message::String) = HTTP.Response(code, json(Dict("status" => "error", "message" => message)))
