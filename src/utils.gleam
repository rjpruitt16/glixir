//// Glixir utility functions
//// 
//// Centralized utilities for environment detection, logging, and common helpers

import envoy
import gleam/option.{None, Some}
import logging

/// Get environment variable with fallback default
pub fn get_env_or(key: String, default: String) -> String {
  option.unwrap(
    case envoy.get(key) {
      Ok(val) -> Some(val)
      Error(_) -> None
    },
    default,
  )
}

/// Check if verbose logging is enabled via VERBOSE environment variable
pub fn is_verbose() -> Bool {
  get_env_or("VERBOSE", "false") == "true"
}

/// Debug logging that respects VERBOSE environment variable
/// Only logs when VERBOSE=true, otherwise silent
pub fn debug_log(level: logging.LogLevel, message: String) -> Nil {
  case is_verbose() {
    True -> logging.log(level, message)
    False -> Nil
  }
}

/// Always log (for critical errors and important messages)
pub fn always_log(level: logging.LogLevel, message: String) -> Nil {
  logging.log(level, message)
}

/// Log with module prefix for better traceability
pub fn debug_log_with_prefix(
  level: logging.LogLevel,
  module_prefix: String,
  message: String,
) -> Nil {
  debug_log(level, "[" <> module_prefix <> "] " <> message)
}

/// Helper for info-level debug logging
pub fn debug_info(message: String) -> Nil {
  debug_log(logging.Info, message)
}

/// Helper for error-level debug logging  
pub fn debug_error(message: String) -> Nil {
  debug_log(logging.Error, message)
}

/// Helper for warning-level debug logging
pub fn debug_warning(message: String) -> Nil {
  debug_log(logging.Warning, message)
}
