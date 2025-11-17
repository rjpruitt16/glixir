defmodule Glixir.SynPubSub do
  @moduledoc """
  Type-safe syn pubsub bridge for Gleam actors, using JSON for interop.
  Similar to Glixir.PubSub but for :syn instead of Phoenix.PubSub.

  Syn pubsub messages arrive as {:syn_event, from_pid, message} tuples.
  """

  require Logger

  # Use Gleam utils module for debug logging
  defp debug_log(level, message) do
    :glixir@utils.debug_log(level, message)
  end

  # Always log (for critical errors)
  defp always_log(level, message) do
    :glixir@utils.always_log(level, message)
  end

  @doc """
  Subscribe to a syn pubsub group with a Gleam callback.

  Similar to Glixir.PubSub.subscribe but for :syn.join instead of Phoenix.PubSub.

  - scope: syn scope name (string, will be converted to atom)
  - group: syn group name (string)
  - gleam_module: module name like "actors@url_queue_actor"
  - gleam_function: function name like "handle_job_cancellation"
  - registry_key: optional key to pass as first argument to callback
  """
  def subscribe(scope, group, gleam_module, gleam_function, registry_key \\ nil)
      when is_binary(scope) and is_binary(group) and is_binary(gleam_module) and is_binary(gleam_function) do

    debug_log(:debug, "[SynPubSub.ex] Subscribing to #{scope}/#{group} (→ #{gleam_module}.#{gleam_function})")

    # Test if the module exists BEFORE spawning
    try do
      gleam_module_atom = String.to_existing_atom(gleam_module)
      debug_log(:debug, "[SynPubSub.ex] Module atom created: #{inspect(gleam_module_atom)}")

      # Test if the function exists (check both 1-arity and 2-arity versions)
      gleam_function_atom = String.to_existing_atom(gleam_function)
      function_arity = if registry_key, do: 2, else: 1

      case function_exported?(gleam_module_atom, gleam_function_atom, function_arity) do
        true ->
          debug_log(:debug, "[SynPubSub.ex] Function confirmed: #{gleam_function}/#{function_arity}")

          # Spawn the handler process
          debug_log(:debug, "[SynPubSub.ex] About to spawn handler process...")

          handler_pid = spawn(fn ->
            debug_log(:debug, "[SynPubSub.ex] Handler process started, subscribing to syn...")

            # Convert scope to atom and join syn pubsub group
            scope_atom = String.to_atom(scope)

            case :syn.join(scope_atom, group, self()) do
              :ok ->
                always_log(:info, "[SynPubSub.ex] ✅ Handler subscribed to #{scope}/#{group}")
                receive_loop(gleam_module, gleam_function, registry_key, scope, group)
              {:error, reason} ->
                always_log(:error, "[SynPubSub.ex] ❌ Handler subscribe failed: #{inspect(reason)}")
            end
          end)

          debug_log(:debug, "[SynPubSub.ex] Handler spawned: #{inspect(handler_pid)}")

          # Give the handler a moment to subscribe
          Process.sleep(10)

          :syn_pubsub_subscribe_ok

        false ->
          always_log(:error, "[SynPubSub.ex] ❌ Function not exported: #{gleam_module}.#{gleam_function}/#{function_arity}")
          {:syn_pubsub_subscribe_error, :function_not_exported}
      end

    rescue
      ArgumentError ->
        always_log(:error, "[SynPubSub.ex] ❌ Module does not exist: #{gleam_module}")
        {:syn_pubsub_subscribe_error, :module_not_found}

      error ->
        always_log(:error, "[SynPubSub.ex] ❌ Unexpected error during subscribe: #{inspect(error)}")
        {:syn_pubsub_subscribe_error, error}
    end
  end

  # Handler receive loop - listens for syn pubsub messages
  defp receive_loop(gleam_module, gleam_function, registry_key, scope, group) do
    receive do
      # Syn pubsub messages arrive as {:syn_event, from_pid, message}
      {:syn_event, from_pid, msg} ->
        debug_log(:debug, "[SynPubSub.ex] 🎯 Handler received syn_event from #{inspect(from_pid)}: #{inspect(msg)}")

        try do
          # Convert message to string - handle different formats
          string_message = case msg do
            s when is_binary(s) ->
              s
            iolist when is_list(iolist) ->
              # Handle nested IO list from Gleam's json.to_string
              IO.iodata_to_binary(iolist)
            other ->
              # Fallback to inspect for other types
              inspect(other)
          end

          gleam_module_atom = String.to_existing_atom(gleam_module)
          gleam_function_atom = String.to_existing_atom(gleam_function)

          # Call function with or without registry key
          _result = if registry_key do
            debug_log(:debug, "[SynPubSub.ex] Calling #{gleam_module_atom}.#{gleam_function_atom}(#{registry_key}, #{string_message})")
            apply(gleam_module_atom, gleam_function_atom, [registry_key, string_message])
          else
            debug_log(:debug, "[SynPubSub.ex] Calling #{gleam_module_atom}.#{gleam_function_atom}(#{string_message})")
            apply(gleam_module_atom, gleam_function_atom, [string_message])
          end

          debug_log(:debug, "[SynPubSub.ex] ✅ Handler call successful")

        rescue
          ArgumentError ->
            always_log(:error, "[SynPubSub.ex] ❌ Module not found: #{gleam_module}")

          UndefinedFunctionError ->
            always_log(:error, "[SynPubSub.ex] ❌ Function not found: #{gleam_module}.#{gleam_function}")

          error ->
            always_log(:error, "[SynPubSub.ex] ❌ Error calling handler: #{inspect(error)}")
        end

        receive_loop(gleam_module, gleam_function, registry_key, scope, group)

      # Handle other message formats if needed
      other ->
        debug_log(:debug, "[SynPubSub.ex] ⚠️  Received unexpected message format: #{inspect(other)}")
        receive_loop(gleam_module, gleam_function, registry_key, scope, group)
    end
  end

  @doc """
  Publish a message to all subscribers of a syn pubsub group.

  Returns the number of processes the message was delivered to.
  """
  def publish(scope, group, message) when is_binary(scope) and is_binary(group) do
    debug_log(:debug, "[SynPubSub.ex] Publishing to #{scope}/#{group}")

    scope_atom = String.to_atom(scope)

    case :syn.publish(scope_atom, group, message) do
      {:ok, count} ->
        debug_log(:debug, "[SynPubSub.ex] Published to #{count} subscribers")
        {:syn_pubsub_publish_ok, count}
      {:error, reason} ->
        {:syn_pubsub_publish_error, reason}
    end
  end
end
