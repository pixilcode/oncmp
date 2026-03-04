import gleam/option.{type Option, None, Some}
import gleam/string

pub type Args {
  Args(
    config_loc: Option(String),
    mode: Mode,
    skip_unchanged: Bool,
    show_help: Bool,
  )
}

pub const help_message = "Usage: oncmp [OPTIONS]

Compare parameters and tests between old and new Oneil runs.

Options:
  -h, --help           Show this help message and exit
  --config <path>      Path to config file (default: ./oncmp_config.toml)
  -t, --tests          Show only test diffs
  -p, --params         Show only parameter diffs
  -s, --skip-unchanged Omit unchanged items from output
"

pub type Mode {
  All
  Params
  Tests
}

fn default_args() -> Args {
  Args(config_loc: None, mode: All, skip_unchanged: False, show_help: False)
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
    ["--tests", ..rest] | ["-t", ..rest] -> {
      parse_args_inner(rest, Args(..args, mode: Tests))
    }
    ["--params", ..rest] | ["-p", ..rest] -> {
      parse_args_inner(rest, Args(..args, mode: Params))
    }
    ["--skip-unchanged", ..rest] | ["-s", ..rest] -> {
      parse_args_inner(rest, Args(..args, skip_unchanged: True))
    }
    ["--help", ..rest] | ["-h", ..rest] -> {
      parse_args_inner(rest, Args(..args, show_help: True))
    }
    [arg, ..] -> {
      Error("invalid arg: " <> arg)
    }
  }
}
