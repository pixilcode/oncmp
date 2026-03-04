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

pub fn load(config_loc: Option(String)) -> Result(Config, String) {
  let config_loc = config_loc |> option.unwrap(or: default_config_loc)
  load_config(config_loc)
}

fn load_config(config_loc: String) -> Result(Config, String) {
  use file_contents <- result.try(
    simplifile.read(config_loc)
    |> result.map_error(simplifile.describe_error),
  )

  use toml_config <- result.try(
    tom.parse(file_contents)
    |> result.map_error(describe_toml_parse_error),
  )

  use ignore_params <- result.try(
    toml_config
    |> tom.get_array(["ignore", "params"])
    |> use_default_if_not_found(default: [])
    |> result.map(list.map(_, tom.as_string))
    |> result.map(result.all)
    |> result.flatten()
    |> result.map_error(describe_toml_get_error),
  )

  use ignore_tests <- result.try(
    toml_config
    |> tom.get_array(["ignore", "tests"])
    |> use_default_if_not_found(default: [])
    |> result.map(list.map(_, tom.as_string))
    |> result.map(result.all)
    |> result.flatten()
    |> result.map_error(describe_toml_get_error),
  )

  use old_repo <- result.try(
    toml_config
    |> tom.get_string(["run", "old_repo"])
    |> result.map_error(describe_toml_get_error),
  )

  use new_repo <- result.try(
    toml_config
    |> tom.get_string(["run", "new_repo"])
    |> result.map_error(describe_toml_get_error),
  )

  use model_file <- result.try(
    toml_config
    |> tom.get_string(["run", "model_file"])
    |> result.map_error(describe_toml_get_error),
  )

  Ok(Config(
    ignore_params: ignore_params,
    ignore_tests: ignore_tests,
    old_repo: old_repo,
    new_repo: new_repo,
    model_file: model_file,
  ))
}

fn describe_toml_parse_error(error: tom.ParseError) -> String {
  case error {
    tom.Unexpected(got: got, expected: expected) -> {
      "unexpected token: got '" <> got <> "', expected '" <> expected <> "'"
    }

    tom.KeyAlreadyInUse(key) -> {
      let key_path = key |> key_to_string()
      "key already in use: " <> key_path
    }
  }
}

fn describe_toml_get_error(error: tom.GetError) -> String {
  case error {
    tom.NotFound(key) -> {
      let key_path = key |> key_to_string()
      "key not found: " <> key_path
    }

    tom.WrongType(key: key, expected: expected, got: got) -> {
      let key_path = key |> key_to_string()

      "key has wrong type: "
      <> key_path
      <> " expected '"
      <> expected
      <> "', got '"
      <> got
      <> "'"
    }
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

fn key_to_string(key_path: List(String)) -> String {
  key_path |> string.join(with: ".")
}
