# API routes
HTTP.register!(ROUTER, "GET", "/api/initialize", () -> begin
    global ai_state = initialize_ai_state()
    return HTTP.Response(200, json(Dict(
        "status" => "success",
        "message" => "AI state initialized",
        "system_prompt" => system_prompt(ai_state).content,
        "conversation_id" => ai_state.selected_conv_id,
        "available_conversations" =>  ai_state.conversation,
    )))
end)

HTTP.register!(ROUTER, "POST", "/api/set_path", req -> begin
    path = parse(String(req.body))["path"]
    isempty(path) && return HTTP.Response(400, json(Dict("status" => "error", "message" => "Path not provided")))
    set_project_path(path)
    return HTTP.Response(200, json(Dict("status" => "success", "message" => "Project path set")))
end)

HTTP.register!(ROUTER, "POST", "/api/update_system_prompt", req -> begin
    update_system_prompt!(ai_state, new_system_prompt=parse(String(req.body))["conversation_id"])
    return HTTP.Response(200, json(Dict("status" => "success", "message" => "System prompt updated")))
end)

HTTP.register!(ROUTER, "GET", "/api/refresh_project", () -> begin
    update_system_prompt!(ai_state)
    return HTTP.Response(200, json(Dict("status" => "success", "message" => "System prompt refreshed")))
end)

HTTP.register!(ROUTER, "POST", "/api/new_conversation", () -> begin
    new_id = generate_new_conversation(ai_state)
    return HTTP.Response(200, json(Dict("status" => "success", "message" => "New conversation started", "conversation_id" => new_id)))
end)
HTTP.register!(ROUTER, "POST", "/api/select_conversation", req -> begin
    conversation_id = parse(String(req.body))["conversation_id"]
    isempty(conversation_id) && return HTTP.Response(400, json(Dict("status" => "error", "message" => "Conversation ID not provided")))
    !haskey(ai_state.conversation, conversation_id) && return HTTP.Response(404, json(Dict("status" => "error", "message" => "Conversation not found")))
    (ai_state.selected_conv_id !== conversation_id) && select_conversation(ai_state, conversation_id)
    return HTTP.Response(200, json(Dict("status" => "success", "message" => "Conversation selected and loaded", "history" => conversation_to_dict(ai_state))))
end)

HTTP.register!(ROUTER, "POST", "/api/process_message", req -> begin
    user_message = parse(String(req.body))["message"]
    msg = process_query(ai_state, user_message)    
    return HTTP.Response(200, json(Dict("status" => "success", "response" => msg.content, 
                "timestamp" => Dates.format(msg.timestamp, "yyyy-mm-dd_HH:MM:SS"), 
                "conversation_id" => ai_state.selected_conv_id)))
end)
