import args.{All, Params, Tests}
import argv
import cli/print
import config
import core/diff.{type Diff}
import core/load_output_actor
import core/parse.{type Param, type Test}
import core/run
import gleam/bool
import gleam/io
import gleam/otp/actor
import gleam/result
import gleam/string

pub fn main() -> Nil {
  // load the args
  let parsed_args =
    argv.load().arguments
    |> args.parse_args()
    |> result.map_error(print.print_error_and_help)

  use args <- try_or_return(parsed_args, Nil)

  use <- bool.lazy_guard(when: args.show_help, return: fn() {
    print.print_help()
    Nil
  })

  // unlike later logging, this doesn't log before the action
  // so that the help message doesn't start with "loading args ... "
  io.println("args loaded")

  io.print("loading config ... ")
  let config =
    config.load(args.config_loc)
    |> result.map_error(print.print_error_and_help)

  use config <- try_or_return(config, Nil)
  io.println("done")

  // initialize the "run and parse" actors for old and new Oneil
  let old_actor_result =
    actor.new(load_output_actor.Uninitialized)
    |> actor.on_message(load_output_actor.handle_message(
      "old",
      run.run_old,
      parse.parse_old_output,
      args.print_source_on_parse_error,
    ))
    |> actor.start
    |> result.map_error(actor_start_error_to_string)

  use old_actor <- try_or_return_with_error(old_actor_result, Nil)

  let new_actor_result =
    actor.new(load_output_actor.Uninitialized)
    |> actor.on_message(load_output_actor.handle_message(
      "new",
      run.run_new,
      parse.parse_new_output,
      args.print_source_on_parse_error,
    ))
    |> actor.start
    |> result.map_error(actor_start_error_to_string)

  use new_actor <- try_or_return_with_error(new_actor_result, Nil)

  // run the actors
  actor.send(
    old_actor.data,
    load_output_actor.Run(config.old_repo, config.model_file),
  )

  actor.send(
    new_actor.data,
    load_output_actor.Run(config.new_repo, config.model_file),
  )

  // get the results
  let old_actor_output =
    actor.call(
      old_actor.data,
      waiting: 1_000_000,
      sending: load_output_actor.GetResult,
    )

  use #(old_params, old_tests) <- try_or_return_with_error(
    old_actor_output,
    Nil,
  )

  let new_actor_output =
    actor.call(
      new_actor.data,
      waiting: 1_000_000,
      sending: load_output_actor.GetResult,
    )

  use #(new_params, new_tests) <- try_or_return_with_error(
    new_actor_output,
    Nil,
  )

  // compare the params and tests
  io.print("diffing params ... ")
  let diff_params =
    diff.diff_params(old_params, new_params, config.ignore_params)
  io.println("done")

  io.print("diffing tests ... ")
  let diff_tests = diff.diff_tests(old_tests, new_tests, config.ignore_tests)
  io.println("done")

  // add a blank line between the logs and the results
  io.println("")

  // print out the results
  let include_unchanged = args.include_unchanged
  case args.mode {
    All -> {
      print_params(diff_params, include_unchanged)
      print_tests(diff_tests, include_unchanged)
    }
    Params -> {
      print_params(diff_params, include_unchanged)
    }
    Tests -> {
      print_tests(diff_tests, include_unchanged)
    }
  }

  // add a blank line at the end of the output
  io.println("")

  Nil
}

fn try_or_return(result: Result(a, e), default: b, handle: fn(a) -> b) -> b {
  case result {
    Ok(value) -> handle(value)
    Error(_error) -> {
      default
    }
  }
}

fn try_or_return_with_error(
  result: Result(a, String),
  default: b,
  handle: fn(a) -> b,
) -> b {
  case result {
    Ok(value) -> handle(value)
    Error(error) -> {
      print.print_error(error)
      default
    }
  }
}

fn actor_start_error_to_string(error: actor.StartError) -> String {
  case error {
    actor.InitTimeout -> "actor initialization timed out"
    actor.InitFailed(message) -> "actor initialization failed: " <> message
    actor.InitExited(reason) ->
      "actor initialization exited: " <> string.inspect(reason)
  }
}

fn print_params(diffs: List(Diff(Param)), include_unchanged: Bool) -> Nil {
  io.println("========== PARAMETERS ==========")
  print.print_params_diff(diffs, include_unchanged)
  io.println("")
  print.print_diff_summary(diffs)
  io.println("")
}

fn print_tests(diffs: List(Diff(Test)), include_unchanged: Bool) -> Nil {
  io.println("========== TESTS ==========")
  print.print_tests_diff(diffs, include_unchanged)
  io.println("")
  print.print_diff_summary(diffs)
}
