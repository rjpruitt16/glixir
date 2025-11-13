defmodule Glixir.LibCluster do
  @moduledoc """
  Generic LibCluster wrapper for Gleam applications.
  Supports multiple clustering strategies for different platforms.
  """

  def start_link(app_name, strategy, polling_interval, query)
      when is_binary(app_name) and is_binary(strategy) do
    strategy_module =
      case strategy do
        "dns_poll" -> Cluster.Strategy.DNSPoll
        "gossip" -> Cluster.Strategy.Gossip
        "epmd" -> Cluster.Strategy.Epmd
        "kubernetes" -> Cluster.Strategy.Kubernetes
        "ec2" -> Cluster.Strategy.EC2
        _ -> Cluster.Strategy.DNSPoll
      end

    topology =
      {:"#{app_name}_cluster",
       [
         strategy: strategy_module,
         config: build_config(strategy, app_name, polling_interval, query)
       ]}

    children = [
      {Cluster.Supervisor, [[topology], [name: :"#{app_name}_cluster"]]}
    ]

    case Supervisor.start_link(children, strategy: :one_for_one) do
      {:ok, pid} -> {:cluster_start_ok, pid}
      {:error, {:already_started, pid}} -> {:cluster_start_ok, pid}
      {:error, reason} -> {:cluster_start_error, inspect(reason)}
    end
  end

  defp build_config("dns_poll", app_name, polling_interval, query) do
    [
      polling_interval: polling_interval,
      query: query,
      node_basename: app_name
    ]
  end

  defp build_config("gossip", _app_name, _polling_interval, _query) do
    # Gossip uses multicast, no config needed
    []
  end

  defp build_config("epmd", _app_name, _polling_interval, _query) do
    # Could accept hosts as parameter later
    [hosts: []]
  end

  defp build_config(_, app_name, polling_interval, query) do
    # Default to DNS config for unknown strategies
    build_config("dns_poll", app_name, polling_interval, query)
  end

  # Rest stays the same...
  def start_link_fly(app_name) when is_binary(app_name) do
    app = app_name || System.get_env("FLY_APP_NAME", "app")

    # Use region-specific DNS to cluster only within the same region
    # This creates per-region syn clusters instead of one global cluster
    region = System.get_env("FLY_REGION")
    query = if region, do: "#{region}.#{app}.internal", else: "#{app}.internal"

    start_link(app, "dns_poll", 5_000, query)
  end

  def start_link_local(app_name) when is_binary(app_name) do
    start_link(app_name, "gossip", 5_000, "")
  end

  def connected_nodes(), do: Node.list()
  def node_name(), do: Node.self()
end
