%% glixir_ffi.erl - FFI helper functions for glixir
-module(glixir_ffi).
-export([
    start_genserver/2,
    start_genserver_named/3,
    create_genserver_options/1
]).

%% Start a GenServer without name registration
start_genserver(ModuleName, Args) when is_binary(ModuleName) ->
    Module = binary_to_atom(ModuleName),
    gen_server:start_link(Module, Args, []).

%% Start a GenServer with name registration
start_genserver_named(ModuleName, Name, Args) when is_binary(ModuleName), is_binary(Name) ->
    Module = binary_to_atom(ModuleName),
    NameAtom = binary_to_atom(Name),
    gen_server:start_link({local, NameAtom}, Module, Args, []).

%% Create GenServer options list with name registration (backup function)
create_genserver_options(Name) ->
    [{name, Name}].
