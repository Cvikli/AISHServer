# API routes
HTTP.register!(ROUTER, "GET", "/api/initialize", function(request::HTTP.Request)
    global ai_state = initialize_ai_state(streaming=false)
    return HTTP.Response(200, JSON.json(Dict(
        "status" => "success",
        "message" => "AI state initialized",
        "system_prompt" => system_prompt(ai_state).content,
        "conversation_id" => ai_state.selected_conv_id,
        "available_conversations" => ai_state.conversation,
    )))
end)

HTTP.register!(ROUTER, "POST", "/api/set_path", function(request::HTTP.Request)
    data = JSON.parse(String(request.body))
    path = get(data, "path", "")
    if isempty(path)
        return HTTP.Response(400, JSON.json(Dict("status" => "error", "message" => "Path not provided")))
    end
    set_project_path(path)
    return HTTP.Response(200, JSON.json(Dict("status" => "success", "message" => "Project path set")))
end)

HTTP.register!(ROUTER, "POST", "/api/update_system_prompt", function(request::HTTP.Request)
    data = JSON.parse(String(request.body))
    update_system_prompt!(ai_state, new_system_prompt=get(data, "conversation_id", ""))
    return HTTP.Response(200, JSON.json(Dict("status" => "success", "message" => "System prompt updated")))
end)

HTTP.register!(ROUTER, "GET", "/api/refresh_project", function(request::HTTP.Request)
    update_system_prompt!(ai_state)
    return HTTP.Response(200, JSON.json(Dict("status" => "success", "message" => "System prompt refreshed")))
end)

HTTP.register!(ROUTER, "POST", "/api/new_conversation", function(request::HTTP.Request)
    new_id = generate_new_conversation(ai_state)
    return HTTP.Response(200, JSON.json(Dict("status" => "success", "message" => "New conversation started", "conversation_id" => new_id)))
end)

HTTP.register!(ROUTER, "POST", "/api/select_conversation", function(request::HTTP.Request)
    data = JSON.parse(String(request.body))
    conversation_id = get(data, "conversation_id", "")
    if isempty(conversation_id)
        return HTTP.Response(400, JSON.json(Dict("status" => "error", "message" => "Conversation ID not provided")))
    end
    if !haskey(ai_state.conversation, conversation_id)
        return HTTP.Response(404, JSON.json(Dict("status" => "error", "message" => "Conversation not found")))
    end
    if ai_state.selected_conv_id !== conversation_id
        select_conversation(ai_state, conversation_id)
    end
    return HTTP.Response(200, JSON.json(Dict("status" => "success", "message" => "Conversation selected and loaded", "history" => conversation_to_dict(ai_state))))
end)

HTTP.register!(ROUTER, "POST", "/api/process_message", function(request::HTTP.Request)
    data = JSON.parse(String(request.body))
    user_message = get(data, "message", "")
    msg = process_query(ai_state, user_message)    
    return HTTP.Response(200, JSON.json(Dict(
        "status" => "success", 
        "response" => msg.content, 
        "timestamp" => Dates.format(msg.timestamp, "yyyy-mm-dd_HH:MM:SS"), 
        "conversation_id" => ai_state.selected_conv_id
    )))
end)
