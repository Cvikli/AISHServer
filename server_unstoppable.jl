handle_interrupt(sig::Int32) = (println("\nExiting gracefully."); exit(0))
ccall(:signal, Ptr{Cvoid}, (Cint, Ptr{Cvoid}), 2, @cfunction(handle_interrupt, Cvoid, (Int32,)))

run_server() = include("server.jl")


# while true
    # try
        run_server()
#     catch e
#         isa(e, InterruptException) && (println("\nServer stopped by user. Exiting."); break)
#         @error "Server crashed" exception=(e, catch_backtrace())
#         println("Server crashed. Restarting in 5 seconds...")
#         sleep(5)
#     end
# end
