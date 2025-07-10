defmodule Glixir.Registry do
  @moduledoc """
  Elixir wrapper for Registry functions that converts responses
  into Gleam-compatible tuple formats.
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
  Start a Registry with the given name and key type.

  Key types:
  - "unique" - each key can only be registered once
  - "duplicate" - keys can be registered multiple times

  Returns:
  - {:registry_start_ok, pid} for successful start
  - {:registry_start_error, reason} for errors
  """
  def start_registry(name, keys_type) when is_binary(name) and is_binary(keys_type) do
    debug_log(:debug, "[Registry.ex] Starting Registry: #{name} with keys: #{keys_type}")

    registry_name = String.to_atom(name)
    keys_atom = String.to_atom(keys_type)

    debug_log(:debug, "[Registry.ex] Converted to atoms: registry_name=#{inspect(registry_name)}, keys=#{inspect(keys_atom)}")

    case Registry.start_link(keys: keys_atom, name: registry_name) do
      {:ok, pid} ->
        always_log(:info, "[Registry.ex] ✅ Registry '#{name}' started successfully: #{inspect(pid)}")
        {:registry_start_ok, pid}

      {:error, {:already_started, pid}} ->
        debug_log(:debug, "[Registry.ex] ⚠️ Registry '#{name}' already started: #{inspect(pid)}")
        {:registry_start_ok, pid}

      {:error, reason} ->
        always_log(:error, "[Registry.ex] ❌ Registry '#{name}' start failed: #{inspect(reason)}")
        {:registry_start_error, reason}
    end
  end

  @doc """
  Register a Subject with a key in the registry.

  The subject parameter should be a Gleam Subject tuple: {:subject, pid, ref}

  Returns:
  - :registry_register_ok for successful registration
  - {:registry_register_error, reason} for errors
  """
  def register_subject(registry_name, key, subject)
      when is_binary(registry_name) and is_binary(key) do
    debug_log(:debug, "[Registry.ex] Registering subject in '#{registry_name}' with key: #{key}")
    debug_log(:debug, "[Registry.ex] Subject received: #{inspect(subject)}")

    registry_atom = String.to_atom(registry_name)
    debug_log(:debug, "[Registry.ex] Registry atom: #{inspect(registry_atom)}")

    # Extract the PID from the Gleam Subject tuple
    # Gleam Subject format: {:subject, pid, ref}
    {pid, metadata} =
      case subject do
        {:subject, pid, ref} ->
          debug_log(:debug, "[Registry.ex] ✅ Extracted PID #{inspect(pid)} and ref #{inspect(ref)} from Gleam Subject")

          {pid, %{gleam_subject: subject, ref: ref}}

        pid when is_pid(pid) ->
          debug_log(:debug, "[Registry.ex] ⚠️ Got raw PID: #{inspect(pid)}")
          {pid, %{gleam_subject: subject}}

        other ->
          debug_log(:warning, "[Registry.ex] ⚠️ Unexpected subject format: #{inspect(other)}")
          {other, %{gleam_subject: subject}}
      end

    debug_log(:debug, "[Registry.ex] About to register PID #{inspect(pid)} with key '#{key}' and metadata: #{inspect(metadata)}")

    case Registry.register(registry_atom, key, metadata) do
      {:ok, _owner} ->
        always_log(:info, "[Registry.ex] ✅ Subject registered successfully in '#{registry_name}' with key: #{key}")
        :registry_register_ok

      {:error, {:already_registered, existing_pid}} ->
        debug_log(:warning, "[Registry.ex] ⚠️ Key '#{key}' already registered to #{inspect(existing_pid)}")
        {:registry_register_error, {:already_registered, existing_pid}}

      {:error, reason} ->
        always_log(:error, "[Registry.ex] ❌ Registration failed for key '#{key}': #{inspect(reason)}")
        {:registry_register_error, reason}
    end
  end

  @doc """
  Look up a Subject by key in the registry.

  Returns the original Gleam Subject that was registered.

  Returns:
  - {:registry_lookup_ok, subject} for successful lookup
  - :registry_lookup_not_found if key not found
  - {:registry_lookup_error, reason} for other errors
  """
  def lookup_subject(registry_name, key) when is_binary(registry_name) and is_binary(key) do
    debug_log(:debug, "Looking up subject in '#{registry_name}' with key: #{key}")

    try do
      registry_atom = String.to_atom(registry_name)

      case Registry.lookup(registry_atom, key) do
        [{_pid, metadata}] ->
          # Extract the original Gleam Subject from metadata
          subject = Map.get(metadata, :gleam_subject)
          debug_log(:debug, "Found subject for key '#{key}': #{inspect(subject)}")
          {:registry_lookup_ok, subject}

        [] ->
          debug_log(:debug, "No subject found for key '#{key}' in registry '#{registry_name}'")
          # 🔧 FIX: Return atom, not tuple
          :registry_lookup_not_found

        multiple when is_list(multiple) and length(multiple) > 1 ->
          # Handle duplicate keys (should not happen with unique registry)
          debug_log(:warning, "Multiple entries found for key '#{key}': #{inspect(multiple)}")
          [{_pid, metadata} | _] = multiple
          subject = Map.get(metadata, :gleam_subject)
          {:registry_lookup_ok, subject}
      end
    rescue
      ArgumentError ->
        # Registry doesn't exist
        debug_log(:debug, "Registry '#{registry_name}' does not exist")
        {:registry_lookup_error, :registry_not_found}

      error ->
        always_log(:error, "Exception during lookup for key '#{key}': #{inspect(error)}")
        {:registry_lookup_error, error}
    end
  end

  @doc """
  Unregister a key from the registry.

  This removes the current process's registration for the given key.

  Returns:
  - :registry_unregister_ok for successful unregistration
  - {:registry_unregister_error, reason} for errors
  """
  def unregister_subject(registry_name, key) when is_binary(registry_name) and is_binary(key) do
    debug_log(:debug, "Unregistering key '#{key}' from registry '#{registry_name}'")

    try do
      registry_atom = String.to_atom(registry_name)

      case Registry.unregister(registry_atom, key) do
        :ok ->
          always_log(:info, "Successfully unregistered key '#{key}' from registry '#{registry_name}'")
          :registry_unregister_ok

        {:error, reason} ->
          always_log(:error, "Unregistration failed for key '#{key}': #{inspect(reason)}")
          {:registry_unregister_error, reason}
      end
    rescue
      error ->
        always_log(:error, "Exception during unregistration for key '#{key}': #{inspect(error)}")
        {:registry_unregister_error, error}
    end
  end
end
