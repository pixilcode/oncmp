import gleam/option.{type Option, None, Some}
import gleam/string

pub type Args {
  Args(config_loc: Option(String))
}

fn default_args() -> Args {
  Args(config_loc: None)
}

pub fn parse_args(arg_strs: List(String)) -> Result(Args, String) {
  parse_args_inner(arg_strs, default_args())
}

fn parse_args_inner(arg_strs: List(String), args: Args) -> Result(Args, String) {
  case arg_strs {
    [] -> Ok(args)
    ["--config", config_loc, ..rest] -> {
      case string.trim(config_loc) {
        "" -> Error("config location is empty")
        config_loc -> {
          parse_args_inner(rest, Args(..args, config_loc: Some(config_loc)))
        }
      }
    }
    ["--config"] -> {
      Error("config location is required")
    }
    [arg, ..] -> {
      Error("invalid arg: " <> arg)
    }
  }
}
