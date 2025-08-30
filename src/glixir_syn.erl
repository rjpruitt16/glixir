-module(glixir_syn).
-export([whereis_name/2, register/4, unregister/2, lookup/2, members/2, is_member/3]).

%% Helper to call Gleam's logging functions
log_debug(Message) ->
    'glixir@utils':debug_log_with_prefix(info, <<"glixir_syn">>, list_to_binary(Message)).

%% Bridge function for registration
register(Scope, Name, Pid, Metadata) when is_binary(Scope), is_binary(Name), is_pid(Pid) ->
    ScopeAtom = binary_to_atom(Scope, utf8),
    log_debug(io_lib:format("Registering: Scope=~p, Name=~p, Pid=~p, Metadata=~p", 
                            [ScopeAtom, Name, Pid, Metadata])),
    
    % Use the 4-argument version of syn:register
    Result = syn:register(ScopeAtom, Name, Pid, Metadata),
    
    case Result of
        ok ->
            syn_register_ok;
        {error, Reason} ->
            {syn_register_error, Reason}
    end.

%% Use syn:lookup instead of whereis_name since whereis_name doesn't return metadata
whereis_name(Scope, Name) when is_binary(Scope), is_binary(Name) ->
    ScopeAtom = binary_to_atom(Scope, utf8),
    
    % Use lookup which returns {Pid, Metadata}
    Result = syn:lookup(ScopeAtom, Name),
    log_debug(io_lib:format("whereis using lookup, raw result: ~p", [Result])),
    
    case Result of
        undefined ->
            syn_not_found;
        {Pid, Metadata} when is_pid(Pid) ->
            {syn_found_with_metadata, Pid, Metadata};
        Other ->
            {syn_error, Other}
    end.

%% Rest of the functions remain the same...
unregister(Scope, Name) when is_binary(Scope), is_binary(Name) ->
    ScopeAtom = binary_to_atom(Scope, utf8),
    
    case syn:unregister(ScopeAtom, Name) of
        ok ->
            syn_unregister_ok;
        {error, Reason} ->
            {syn_unregister_error, Reason}
    end.

lookup(Scope, Name) when is_binary(Scope), is_binary(Name) ->
    ScopeAtom = binary_to_atom(Scope, utf8),
    
    Result = syn:lookup(ScopeAtom, Name),
    log_debug(io_lib:format("lookup raw result: ~p", [Result])),
    
    case Result of
        undefined ->
            syn_lookup_not_found;
        {Pid, Metadata} when is_pid(Pid) ->
            {syn_lookup_found, Pid, Metadata};
        Other ->
            {syn_lookup_error, Other}
    end.

members(Scope, Group) when is_binary(Scope), is_binary(Group) ->
    ScopeAtom = binary_to_atom(Scope, utf8),
    
    Result = syn:members(ScopeAtom, Group),
    log_debug(io_lib:format("members raw result: ~p", [Result])),
    
    case Result of
        [] ->
            syn_members_empty;
        Members when is_list(Members) ->
            % Transform {Pid, Meta} to {Name, Pid, Meta} format
            TransformedMembers = lists:map(fun
                ({Pid, Meta}) -> {<<"">>, Pid, Meta};
                (Pid) when is_pid(Pid) -> {<<"">>, Pid, undefined}
            end, Members),
            {syn_members_list, TransformedMembers};
        Other ->
            {syn_members_error, Other}
    end.

is_member(Scope, Name, Pid) when is_binary(Scope), is_binary(Name), is_pid(Pid) ->
    ScopeAtom = binary_to_atom(Scope, utf8),
    
    case syn:is_member(ScopeAtom, Name, Pid) of
        true ->
            syn_is_member_true;
        false ->
            syn_is_member_false;
        {error, Reason} ->
            {syn_is_member_error, Reason}
    end.
