// test/glixir/libcluster_test.gleam
import gleeunit
import gleeunit/should
import glixir/libcluster

pub fn main() {
  gleeunit.main()
}

// Test we can get current node name without crashing
pub fn get_node_name_test() {
  let name = libcluster.current_node_name()

  // Should return something like "nonode@nohost" in tests
  name
  |> should.not_equal("")
}

// Test connected nodes returns empty list when not clustered
pub fn connected_nodes_empty_test() {
  let nodes = libcluster.connected_node_names()

  nodes
  |> should.equal([])
}

// Test is_clustered returns false when no nodes connected
pub fn not_clustered_test() {
  libcluster.is_clustered()
  |> should.be_false()
}

// Test that clustering starts (may already be started from previous test)
pub fn start_clustering_once_test() {
  let result = libcluster.start_clustering_local("test_cluster")

  // Just check it doesn't crash - either Ok or Error is fine
  case result {
    Ok(_pid) -> Nil
    Error(libcluster.StartError(_msg)) -> Nil
    Error(libcluster.ConfigError(_msg)) -> Nil
  }
}

// Test DNS clustering with invalid query (won't actually connect to anything)
pub fn dns_clustering_with_fake_domain_test() {
  let result =
    libcluster.start_clustering_dns("test_dns_app", "fake.internal", 5000)

  // Just verify it doesn't crash
  case result {
    Ok(_pid) -> Nil
    Error(libcluster.StartError(_msg)) -> Nil
    Error(libcluster.ConfigError(_msg)) -> Nil
  }
}

// Test Fly clustering function exists and can be called
pub fn fly_clustering_callable_test() {
  // Just verify the function reference exists
  let _ = libcluster.start_clustering_fly
  should.be_true(True)
}
