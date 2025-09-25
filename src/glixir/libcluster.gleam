import gleam/erlang/atom.{type Atom}
import gleam/erlang/process.{type Pid}
import gleam/list
import logging

/// Clustering strategy types
pub type ClusterStrategy {
  DNSPoll
  Gossip
  Kubernetes
  EPMD
  EC2
}

/// Result types for FFI
pub type ClusterStartResult {
  ClusterStartOk(pid: Pid)
  ClusterStartError(reason: String)
}

pub type ClusterError {
  StartError(String)
  ConfigError(String)
}

// ============ FFI BINDINGS ==============
// Simplified - let Elixir handle the options building
@external(erlang, "Elixir.Glixir.LibCluster", "start_link")
fn start_link_ffi(
  app_name: String,
  strategy: String,
  polling_interval: Int,
  query: String,
) -> ClusterStartResult

@external(erlang, "Elixir.Glixir.LibCluster", "start_link_fly")
fn start_link_fly_ffi(app_name: String) -> ClusterStartResult

@external(erlang, "Elixir.Glixir.LibCluster", "start_link_local")
fn start_link_local_ffi(app_name: String) -> ClusterStartResult

@external(erlang, "Elixir.Glixir.LibCluster", "connected_nodes")
pub fn connected_nodes() -> List(Atom)

@external(erlang, "Elixir.Glixir.LibCluster", "node_name")
pub fn node_name() -> Atom

// ============ PUBLIC API ==============

/// Start clustering with DNS poll (most common for production)
pub fn start_clustering_dns(
  app_name: String,
  query: String,
  polling_interval: Int,
) -> Result(Pid, ClusterError) {
  logging.log(
    logging.Info,
    "[LibCluster] Starting DNS clustering for: " <> app_name,
  )

  case start_link_ffi(app_name, "dns_poll", polling_interval, query) {
    ClusterStartOk(pid) -> {
      logging.log(logging.Info, "[LibCluster] Clustering started successfully")
      Ok(pid)
    }
    ClusterStartError(reason) -> {
      logging.log(logging.Error, "[LibCluster] Failed to start: " <> reason)
      Error(StartError(reason))
    }
  }
}

/// Start clustering for Fly.io (uses DNS polling automatically)
pub fn start_clustering_fly(app_name: String) -> Result(Pid, ClusterError) {
  logging.log(logging.Info, "[LibCluster] Starting Fly.io clustering")

  case start_link_fly_ffi(app_name) {
    ClusterStartOk(pid) -> {
      logging.log(
        logging.Info,
        "[LibCluster] Fly.io clustering started for: " <> app_name,
      )
      Ok(pid)
    }
    ClusterStartError(reason) -> Error(StartError(reason))
  }
}

/// Start clustering for local development (uses Gossip)
pub fn start_clustering_local(app_name: String) -> Result(Pid, ClusterError) {
  logging.log(logging.Info, "[LibCluster] Starting local clustering")

  case start_link_local_ffi(app_name) {
    ClusterStartOk(pid) -> {
      logging.log(logging.Info, "[LibCluster] Local clustering started")
      Ok(pid)
    }
    ClusterStartError(reason) -> Error(StartError(reason))
  }
}

/// Get list of connected node names as strings
pub fn connected_node_names() -> List(String) {
  connected_nodes()
  |> list.map(atom.to_string)
}

/// Get current node name as string
pub fn current_node_name() -> String {
  node_name()
  |> atom.to_string
}

/// Check if clustering is active (has connected nodes)
pub fn is_clustered() -> Bool {
  list.length(connected_nodes()) > 0
}
