import gleam/list
import gleam/option.{type Option}
import gleam/result
import gleam/string
import simplifile
import tom

const default_config_loc = "./oncmp_config.toml"

pub type Config {
  Config(
    ignore_params: List(String),
    ignore_tests: List(String),
    old_repo: String,
    new_repo: String,
    model_file: String,
  )
}

pub type Error {
  FileReadError(path: String, message: String)
  UnexpectedToken(got: String, expected: String)
  KeyAlreadyInUse(key: List(String))
  KeyNotFound(key: List(String))
  KeyWrongType(key: List(String), expected: String, got: String)
}

pub fn load(config_loc: Option(String)) -> Result(Config, Error) {
  let config_loc = config_loc |> option.unwrap(or: default_config_loc)
  load_config(config_loc)
}

fn load_config(config_loc: String) -> Result(Config, Error) {
  use file_contents <- result.try(
    simplifile.read(config_loc)
    |> result.map_error(fn(error) {
      FileReadError(path: config_loc, message: simplifile.describe_error(error))
    }),
  )

  use toml_config <- result.try(
    tom.parse(file_contents)
    |> result.map_error(toml_parse_error),
  )

  use ignore_params <- result.try(
    toml_config
    |> tom.get_array(["ignore", "params"])
    |> use_default_if_not_found(default: [])
    |> result.map(list.map(_, tom.as_string))
    |> result.map(result.all)
    |> result.flatten()
    |> result.map_error(toml_get_error),
  )

  use ignore_tests <- result.try(
    toml_config
    |> tom.get_array(["ignore", "tests"])
    |> use_default_if_not_found(default: [])
    |> result.map(list.map(_, tom.as_string))
    |> result.map(result.all)
    |> result.flatten()
    |> result.map_error(toml_get_error),
  )

  use old_repo <- result.try(
    toml_config
    |> tom.get_string(["run", "old_repo"])
    |> result.map_error(toml_get_error),
  )

  use new_repo <- result.try(
    toml_config
    |> tom.get_string(["run", "new_repo"])
    |> result.map_error(toml_get_error),
  )

  use model_file <- result.try(
    toml_config
    |> tom.get_string(["run", "model_file"])
    |> result.map_error(toml_get_error),
  )

  Ok(Config(
    ignore_params: ignore_params,
    ignore_tests: ignore_tests,
    old_repo: old_repo,
    new_repo: new_repo,
    model_file: model_file,
  ))
}

fn toml_parse_error(error: tom.ParseError) -> Error {
  case error {
    tom.Unexpected(got:, expected:) -> UnexpectedToken(got:, expected:)
    tom.KeyAlreadyInUse(key) -> KeyAlreadyInUse(key:)
  }
}

fn toml_get_error(error: tom.GetError) -> Error {
  case error {
    tom.NotFound(key) -> KeyNotFound(key:)
    tom.WrongType(key:, expected:, got:) -> KeyWrongType(key:, expected:, got:)
  }
}

fn use_default_if_not_found(
  value: Result(a, tom.GetError),
  default default: a,
) -> Result(a, tom.GetError) {
  case value {
    Ok(value) -> Ok(value)
    Error(tom.NotFound(_)) -> Ok(default)
    Error(error) -> Error(error)
  }
}

pub fn error_to_string(error: Error) -> String {
  case error {
    FileReadError(path:, message:) ->
      "failed to read config file " <> string.inspect(path) <> ": " <> message
    UnexpectedToken(got:, expected:) ->
      "unexpected token: got '" <> got <> "', expected '" <> expected <> "'"
    KeyAlreadyInUse(key) -> "key already in use: " <> key_to_string(key)
    KeyNotFound(key) -> "key not found: " <> key_to_string(key)
    KeyWrongType(key:, expected:, got:) ->
      "key has wrong type: "
      <> key_to_string(key)
      <> " expected '"
      <> expected
      <> "', got '"
      <> got
      <> "'"
  }
}

fn key_to_string(key_path: List(String)) -> String {
  key_path |> string.join(with: ".")
}
