%% glixir_ffi.erl - FFI helper functions for glixir (SAFER: uses binary_to_existing_atom)
-module(glixir_ffi).
-export([
    start_genserver/2,
    start_genserver_named/3,
    create_genserver_options/1
]).

%% Helper: Convert a string/binary to an *existing* atom, else error
-spec to_existing_atom(binary()) -> atom() | no_return().
to_existing_atom(Bin) when is_binary(Bin) ->
    try binary_to_existing_atom(Bin, utf8)
    catch
        error:badarg ->
            erlang:error({bad_atom, Bin})
    end.

%% Start a GenServer without name registration
start_genserver(ModuleName, Args) when is_binary(ModuleName) ->
    Module = to_existing_atom(ModuleName),
    gen_server:start_link(Module, Args, []).

%% Start a GenServer with name registration
start_genserver_named(ModuleName, Name, Args) when is_binary(ModuleName), is_binary(Name) ->
    Module = to_existing_atom(ModuleName),
    NameAtom = to_existing_atom(Name),
    gen_server:start_link({local, NameAtom}, Module, Args, []).

%% Create GenServer options list with name registration (backup function)
create_genserver_options(Name) ->
    [{name, Name}].

