using PackageCompiler

# List of packages to precompile
packages_to_precompile = [
    "HTTP",
    "JSON",
    "Anthropic",
    "Revise",
]

# Create the custom system image
create_sysimage(
    packages_to_precompile;
    sysimage_path="CustomAISHServer.so",
    precompile_execution_file="server.jl"
)

println("Custom system image created: CustomAISHServer.so")
