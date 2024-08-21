# API routes
HTTP.register!(ROUTER, "GET", "/api/initialize", function(request::HTTP.Request)
    global ai_state = initialize_ai_state(streaming=false, skip_code_execution=true)
    return OK(Dict(
        "status" => "success",
        "message" => "AI state initialized",
        "conversation_id" => ai_state.selected_conv_id,
        "system_prompt" => system_message(ai_state),
        "available_conversations" => ai_state.conversations,
    ))
end)

HTTP.register!(ROUTER, "POST", "/api/set_path", function(request::HTTP.Request)
    data = parse(String(request.body))
    path = get(data, "path", "")
    isempty(path) && return HTTP.Response(400, json(Dict("status" => "error", "message" => "Path not provided")))
    update_project_path_and_sysprompt!(ai_state, [path])
    return OK(Dict("status" => "success", "message" => "Project path set", "system_prompt" => system_message(ai_state)))
end)

HTTP.register!(ROUTER, "POST", "/api/new_conversation", function(request::HTTP.Request)
    conversation = generate_new_conversation(ai_state)
    @show conversation
    return OK(Dict("status" => "success", 
        "message" => "New conversation started", 
        "system_prompt" => system_message(ai_state),
        "conversation" => conversation))
end)

HTTP.register!(ROUTER, "POST", "/api/select_conversation", function(request::HTTP.Request)
    data = parse(String(request.body))
    conversation_id = get(data, "conversation_id", "")
    if isempty(conversation_id)
        return HTTP.Response(400, json(Dict("status" => "error", "message" => "Conversation ID not provided")))
    end
    if !haskey(ai_state.conversations, conversation_id)
        return HTTP.Response(404, json(Dict("status" => "error", "message" => "Conversation not found")))
    end
    ai_state.selected_conv_id !== conversation_id && select_conversation(ai_state, conversation_id)
    return OK(Dict("status" => "success", 
        "message" => "Conversation selected and loaded", 
        "history" => to_dict_nosys_detailed(ai_state),
        "system_prompt" => system_message(ai_state)))
end)

HTTP.register!(ROUTER, "POST", "/api/process_message", function(request::HTTP.Request)
    data = parse(String(request.body))
    msg = process_question(ai_state, get(data, "message", ""))    
    return OK(Dict(
        "status" => "success", 
        "timestamp" => datetime2unix(msg.timestamp), 
        "conversation_id" => ai_state.selected_conv_id,
        "response" => msg.content, 
    ))
end)

HTTP.register!(ROUTER, "GET", "/api/get_current_path", function(request::HTTP.Request)
    return OK(Dict(
        "status" => "success",
        "current_path" => curr_conv(ai_state).rel_project_paths[1]
    ))
end)

HTTP.register!(ROUTER, "POST", "/api/list_items", function(request::HTTP.Request)
    data = parse(String(request.body))
    path = get(data, "path", "")   
    project_path = isempty(path) ? isempty(curr_conv(ai_state).rel_project_paths) ? pwd() : curr_conv(ai_state).rel_project_paths[1] : path
    @show project_path
    return OK(Dict(
        "status" => "success",
        "current_path" => project_path,
        "folders" => [item for item in readdir(project_path) if isdir(joinpath(project_path, item))],
        "files" => [item for item in readdir(project_path) if isfile(joinpath(project_path, item))]
    ))
end)

HTTP.register!(ROUTER, "POST", "/api/execute_block", function(request::HTTP.Request)
    data = parse(String(request.body))
    code = get(data, "code", "")
    if isempty(code)
        return HTTP.Response(400, json(Dict("status" => "error", "message" => "Code block not provided")))
    end
    
    result = cmd_all_info(`zsh -c $code`)
    @show result
    
    return OK(Dict(
        "status" => "success",
        "result" => result
    ))
end)

OK(data) = return HTTP.Response(200, json(data))

