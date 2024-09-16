HTTP.register!(ROUTER, "GET", "/api/initialize", req -> begin
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
    !("path" in keys(data)) && return ERROR(400, "Path not provided")
    update_project_path_and_sysprompt!(ai_state, [data["path"]])
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
    if ai_state.selected_conv_id !== conversation_id 
        file_exists = select_conversation(ai_state, conversation_id)
        !file_exists && return ERROR(404, "Conversation not found")
    end
   
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
    project_path = isempty(path) ? isempty(curr_conv(ai_state).rel_project_paths) ? pwd() : curr_proj_path(ai_state) : path
    @show project_path
    OK("Items listed", Dict(
        "project_path" => project_path,
        "folders" => [item for item in readdir(project_path) if isdir(joinpath(project_path, item))],
        "files" => [item for item in readdir(project_path) if isfile(joinpath(project_path, item))]
    ))
end)

HTTP.register!(ROUTER, "POST", "/api/get_whole_changes", req -> begin
    try
        data = parse(String(req.body))
        code = get(data, "code", "")
        isempty(code) && return ERROR(400, "Code block not provided")
        
        file_path, original_content, ai_generated_content = generate_ai_command_from_meld_code(code)
        isempty(file_path) && return ERROR(400, "we couldn't generate the ai_command... maybe path problem? or file wrong format... or something?")

        # Generate diff directly from strings
        result, _ = diff_contents(String(original_content), String(ai_generated_content))
        
        cuttedpart = split(code, "\n")
        result = [(:equal, "$(cuttedpart[1])\n", "", "") ; result; (:equal, "$(join(cuttedpart[end-2:end],'\n'))", "", "")]

        ai_generated_content = "$(cuttedpart[1])\n" * ai_generated_content * "$(join(cuttedpart[end-2:end],'\n'))"

        OK("Diff generated successfully", Dict(
            "file_path" => file_path,
            "original_content" => original_content,
            "ai_generated_content" => ai_generated_content,
            "diff" => result
        ))
    catch e
        error_message = "Error generating diff: $(sprint(showerror, e))"
        @error error_message exception=(e, catch_backtrace())
        ERROR(500, error_message)
    end
end)

HTTP.register!(ROUTER, "POST", "/api/execute_block", req -> begin
    try
        data = parse(String(req.body))
        code, timestamp = get(data, "code", ""), get(data, "timestamp", nothing)
        (isempty(code) || isnothing(timestamp)) && return ERROR(400, "Code block or timestamp not provided")
        
        result = execute_single_shell_command(ai_state, code)
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

# New endpoint for saving a file
HTTP.register!(ROUTER, "POST", "/api/save_file", req -> begin
    try
        data = parse(String(req.body))
        filepath = get(data, "filepath", "")
        content = get(data, "content", "")
        
        isempty(filepath) && return ERROR(400, "File path not provided")
        isempty(content) && return ERROR(400, "Content not provided")
        
        write(filepath, content)
        
        OK("File saved successfully", Dict("filepath" => filepath))
    catch e
        error_message = "Error saving file: $(sprint(showerror, e))"
        @error error_message exception=(e, catch_backtrace())
        ERROR(500, error_message)
    end
end)

# New endpoint for retrieving a file
HTTP.register!(ROUTER, "GET", "/api/get_file", req -> begin
    try
        filepath = HTTP.queryparams(HTTP.URI(req.target))["filepath"]
        
        isempty(filepath) && return ERROR(400, "File path not provided")
        !isfile(filepath) && return ERROR(404, "File not found")
        
        content = read(filepath, String)
        
        OK("File content retrieved", Dict("filepath" => filepath, "content" => content))
    catch e
        error_message = "Error retrieving file: $(sprint(showerror, e))"
        @error error_message exception=(e, catch_backtrace())
        ERROR(500, error_message)
    end
end)

OK(data::Dict) = HTTP.Response(200, json(Dict("status" => "success", "message" => "", data...)))
OK(message::String, data::Dict) = HTTP.Response(200, json(Dict("status" => "success", "message" => message, data...)))
ERROR(code::Int, message::String) = HTTP.Response(code, json(Dict("status" => "error", "message" => message)))
