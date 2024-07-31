using AISH 
using Genie, Genie.Renderer, Genie.Renderer.Html, Genie.Renderer.Json


route("/", method = GET) do 
  html("Hello World")
end
# curl -X GET http://localhost:8000/api/initialize
route("/api/initialize", method = GET) do 
  html("Hello initialize")
end
# curl -X POST http://localhost:8000/api/set_path -d '{"path": "/path/to/project"}'
route("/api/set_path", method = POST) do 
  html("Hello set_path")
end
# curl -X POST http://localhost:8000/api/refresh_project
route("/api/refresh_project", method = POST) do 
  html("Hello refresh_project")
end
# curl -X POST http://localhost:8000/api/new_conversation
route("/api/new_conversation", method = POST) do 
  html("Hello new_conversation")
end
# curl -X GET http://localhost:8000/api/conversation_history '{"conversation_id": "lfjweflkjwefklj"}'
route("/api/select_converstaion", method = GET) do 
  html("Hello select_converstaion")
end
# curl -X POST http://localhost:8000/api/process_message -d '{"message": "User message here"}'
route("/api/process_message", method = POST) do 
  html("Hello process_message")
end
# curl -X GET http://localhost:8000/api/project_structure
# curl -X PUT http://localhost:8000/api/change_model -d '{"model": "new-model-name"}'
# curl -X POST http://localhost:8000/api/execute_command -d '{"command": "ls -la"}'
# curl -X PUT http://localhost:8000/api/update_system_prompt -d '{"prompt": "New system prompt"}'


up(8001, async = false)