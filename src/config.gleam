import gleam/dict
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/result
import gleam/string
import simplifile
import tom

const default_config_loc = "./config.toml"

pub type Config {
  Config(ignore_params: List(String), ignore_tests: List(String))
}

pub fn load(config_loc: Option(String)) -> Result(Option(Config), String) {
  case config_loc {
    None ->
      load_config(default_config_loc)
      |> result.map(Some)
      |> result.or(Ok(None))
    Some(config_loc) ->
      load_config(config_loc)
      |> result.map(Some)
  }
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
    |> dict.get("ignore_params")
    |> result.map(tom.as_array)
    |> result.unwrap(or: Ok([]))
    |> result.map(list.map(_, tom.as_string))
    |> result.map(result.all)
    |> result.flatten()
    |> result.map_error(describe_toml_get_error),
  )

  use ignore_tests <- result.try(
    toml_config
    |> dict.get("ignore_tests")
    |> result.map(tom.as_array)
    |> result.unwrap(or: Ok([]))
    |> result.map(list.map(_, tom.as_string))
    |> result.map(result.all)
    |> result.flatten()
    |> result.map_error(describe_toml_get_error),
  )

  Ok(Config(ignore_params: ignore_params, ignore_tests: ignore_tests))
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

fn key_to_string(key_path: List(String)) -> String {
  key_path |> string.join(with: ".")
}
