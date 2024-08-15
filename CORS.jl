

# CORS middleware
function cors_middleware_stream(handler)
    return function(stream::HTTP.Stream)
        request = stream.message
        HTTP.setheader(stream, "Access-Control-Allow-Origin" => "*")
        HTTP.setheader(stream, "Access-Control-Allow-Methods" => "GET, POST, PUT, DELETE, OPTIONS")
        HTTP.setheader(stream, "Access-Control-Allow-Headers" => "Content-Type, Authorization")
        if request.method == "OPTIONS"
            HTTP.setheader(stream, "Access-Control-Max-Age" => "86400")
            HTTP.startwrite(stream)
            return
        end

        # Set CORS headers for the stream
        HTTP.setheader(stream, "Content-Type" => "text/event-stream")
        HTTP.setheader(stream, "Cache-Control" => "no-cache")
        HTTP.setheader(stream, "Connection" => "keep-alive")

        # Call the handler
        return handler(stream)
    end
end

function cors_middleware(handler)
    return function(req::HTTP.Request)
        req.method == "OPTIONS" && return HTTP.Response(200, [
            "Access-Control-Allow-Origin" => "*",
            "Access-Control-Allow-Methods" => "GET, POST, PUT, DELETE, OPTIONS",
            "Access-Control-Allow-Headers" => "Content-Type, Authorization",
            "Access-Control-Max-Age" => "86400"
        ])
        
        response = handler(req)
        
        HTTP.setheader(response, "Access-Control-Allow-Origin" => "*")
        HTTP.setheader(response, "Access-Control-Allow-Methods" => "GET, POST, PUT, DELETE, OPTIONS")
        HTTP.setheader(response, "Access-Control-Allow-Headers" => "Content-Type, Authorization")
        
        return response
    end
end

# Apply CORS middleware to all routes
with_cors_stream(router) = stream -> cors_middleware_stream(HTTP.Handlers.Router(router))(stream)
with_cors(router) = req -> cors_middleware(HTTP.Handlers.Router(router))(req)
