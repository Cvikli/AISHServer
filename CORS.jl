

# CORS middleware
function cors_middleware(handler)
	return function(req::HTTP.Request)
			if HTTP.method(req) == "OPTIONS"
					return HTTP.Response(200, [
							"Access-Control-Allow-Origin" => "*",
							"Access-Control-Allow-Methods" => "GET, POST, PUT, DELETE, OPTIONS",
							"Access-Control-Allow-Headers" => "Content-Type, Authorization"
					])
			end
			
			response = handler(req)
			
			HTTP.setheader(response, "Access-Control-Allow-Origin" => "*")
			HTTP.setheader(response, "Access-Control-Allow-Methods" => "GET, POST, PUT, DELETE, OPTIONS")
			HTTP.setheader(response, "Access-Control-Allow-Headers" => "Content-Type, Authorization")
			
			return response
	end
end

# Apply CORS middleware to all routes
with_cors(router) = req -> cors_middleware(HTTP.Handlers.Router(router))(req)