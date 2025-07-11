defmodule Glixir.PubSub do
  @moduledoc """
  Type-safe Phoenix.PubSub bridge for Gleam actors, using JSON for interop.
  
  IMPORTANT: All PubSub names must be pre-existing atoms to prevent atom table overflow.
  Users are responsible for creating atoms safely before calling these functions.
  """

  require Logger

  # Use Gleam utils module for debug logging (updated path)
  defp debug_log(level, message) do
    :glixir@utils.debug_log(level, message)
  end
  
  # Always log (for critical errors) (updated path)
  defp always_log(level, message) do
    :glixir@utils.always_log(level, message)
  end  

  # --- START PUBSUB ---
  def start(pubsub_name) when is_atom(pubsub_name) do
    debug_log(:debug, "[PubSub.ex] Starting PubSub: #{inspect(pubsub_name)}")

    children = [
      {Phoenix.PubSub, name: pubsub_name}
    ]

    supervisor_name = :"#{pubsub_name}_supervisor"
    
    case Supervisor.start_link(children, strategy: :one_for_one, name: supervisor_name) do
      {:ok, _supervisor_pid} ->
        case Process.whereis(pubsub_name) do
          pid when is_pid(pid) ->
            always_log(:info, "[PubSub.ex] ✅ PubSub started: #{inspect(pid)}")
            {:pubsub_start_ok, pid}
          nil ->
            always_log(:error, "[PubSub.ex] ❌ PubSub process not found after supervisor start")
            {:pubsub_start_error, :pubsub_not_found}
        end

      {:error, {:already_started, _}} ->
        case Process.whereis(pubsub_name) do
          pid when is_pid(pid) ->
            debug_log(:debug, "[PubSub.ex] ⚠️ PubSub already started: #{inspect(pid)}")
            {:pubsub_start_ok, pid}
          nil ->
            {:pubsub_start_error, :pubsub_not_found}
        end

      {:error, reason} ->
        always_log(:error, "[PubSub.ex] ❌ PubSub start failed: #{inspect(reason)}")
        {:pubsub_start_error, reason}
    end
  end

  def subscribe(pubsub_name, topic, gleam_module, gleam_function, registry_key \\ nil)
      when is_atom(pubsub_name) and is_binary(topic) and is_binary(gleam_module) and is_binary(gleam_function) do
    
    debug_log(:debug, "[PubSub.ex] Subscribing to topic '#{topic}' (→ #{gleam_module}.#{gleam_function})")

    # Test if the module exists BEFORE spawning
    try do
      gleam_module_atom = String.to_existing_atom(gleam_module)
      debug_log(:debug, "[PubSub.ex] Module atom created: #{inspect(gleam_module_atom)}")
      
      # Test if the function exists (check both 1-arity and 2-arity versions)
      gleam_function_atom = String.to_existing_atom(gleam_function)
      function_arity = if registry_key, do: 2, else: 1
      
      case function_exported?(gleam_module_atom, gleam_function_atom, function_arity) do
        true ->
          debug_log(:debug, "[PubSub.ex] Function confirmed: #{gleam_function}/#{function_arity}")
          
          # Spawn the handler process
          debug_log(:debug, "[PubSub.ex] About to spawn handler process...")
          
          handler_pid = spawn(fn ->
            debug_log(:debug, "[PubSub.ex] Handler process started, subscribing to PubSub...")
            
            # Subscribe from WITHIN the handler process
            case Phoenix.PubSub.subscribe(pubsub_name, topic) do
              :ok ->
                always_log(:info, "[PubSub.ex] ✅ Handler subscribed to topic '#{topic}'")
                receive_loop(gleam_module, gleam_function, registry_key)
              {:error, reason} ->
                always_log(:error, "[PubSub.ex] ❌ Handler subscribe failed: #{inspect(reason)}")
            end
          end)
          
          debug_log(:debug, "[PubSub.ex] Handler spawned: #{inspect(handler_pid)}")
          
          # Give the handler a moment to subscribe
          Process.sleep(10)
          
          :pubsub_subscribe_ok
          
        false ->
          always_log(:error, "[PubSub.ex] ❌ Function not exported: #{gleam_module}.#{gleam_function}/#{function_arity}")
          {:pubsub_subscribe_error, :function_not_exported}
      end
      
    rescue
      ArgumentError ->
        always_log(:error, "[PubSub.ex] ❌ Module does not exist: #{gleam_module}")
        {:pubsub_subscribe_error, :module_not_found}
        
      error ->
        always_log(:error, "[PubSub.ex] ❌ Unexpected error during subscribe: #{inspect(error)}")
        {:pubsub_subscribe_error, error}
    end
  end

  # --- UPDATED HANDLER LOOP ---
  defp receive_loop(gleam_module, gleam_function, registry_key \\ nil) do
    receive do
      msg ->
        debug_log(:debug, "[PubSub.ex] 🎯 Handler received message: #{inspect(msg)}")
        
        try do
          # Convert message to string - handle different formats
          string_message = case msg do
            s when is_binary(s) -> 
              s
            iolist when is_list(iolist) -> 
              # This handles the nested IO list from Gleam's json.to_string
              IO.iodata_to_binary(iolist)
            other -> 
              # Fallback to inspect for other types
              inspect(other)
          end
          
          gleam_module_atom = String.to_existing_atom(gleam_module)
          gleam_function_atom = String.to_existing_atom(gleam_function)
          
          # Call function with or without registry key
          result = if registry_key do
            debug_log(:debug, "[PubSub.ex] Calling #{gleam_module_atom}.#{gleam_function_atom}(#{registry_key}, #{string_message})")
            apply(gleam_module_atom, gleam_function_atom, [registry_key, string_message])
          else
            debug_log(:debug, "[PubSub.ex] Calling #{gleam_module_atom}.#{gleam_function_atom}(#{string_message})")
            apply(gleam_module_atom, gleam_function_atom, [string_message])
          end
          
          debug_log(:debug, "[PubSub.ex] ✅ Handler call successful")
          
        rescue
          ArgumentError ->
            always_log(:error, "[PubSub.ex] ❌ Module not found: #{gleam_module}")
          
          UndefinedFunctionError ->
            always_log(:error, "[PubSub.ex] ❌ Function not found: #{gleam_module}.#{gleam_function}")
          
          error ->
            always_log(:error, "[PubSub.ex] ❌ Error calling handler: #{inspect(error)}")
        end

        receive_loop(gleam_module, gleam_function, registry_key)
    end
  end  

  # --- BROADCAST ---
  def broadcast(pubsub_name, topic, message) do
    debug_log(:debug, "[PubSub.ex] Broadcasting to topic '#{topic}'")
  
    case Phoenix.PubSub.broadcast(pubsub_name, topic, message) do
      :ok -> :pubsub_broadcast_ok
      {:error, reason} -> {:pubsub_broadcast_error, reason}
    end
  end
  
  # --- UNSUBSCRIBE ---
  def unsubscribe(pubsub_name, topic)
      when is_atom(pubsub_name) and is_binary(topic) do
    
    debug_log(:debug, "[PubSub.ex] Unsubscribing from topic '#{topic}'")

    case Phoenix.PubSub.unsubscribe(pubsub_name, topic) do
      :ok ->
        always_log(:info, "[PubSub.ex] ✅ Unsubscribed from topic '#{topic}'")
        :pubsub_unsubscribe_ok

      {:error, reason} ->
        always_log(:error, "[PubSub.ex] ❌ Unsubscribe failed: #{inspect(reason)}")
        {:pubsub_unsubscribe_error, reason}
    end
  end
end
