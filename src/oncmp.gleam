import argv
import gleam/bool
import gleam/io
import gleam/result

import args.{All, Params, Tests}
import config
import diff.{type Diff}
import parse.{type Param, type Test}
import print
import run

pub fn main() -> Nil {
  let parsed_args =
    argv.load().arguments
    |> args.parse_args()
    |> result.map_error(print.print_error_and_help)

  use <- bool.guard(when: parsed_args |> result.is_error(), return: Nil)
  let assert Ok(args) = parsed_args

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

  use <- bool.guard(when: config |> result.is_error(), return: Nil)
  let assert Ok(config) = config
  io.println("done")

  // get the output from running the old and new versions of Oneil
  io.print("running old Oneil ... ")
  let old_output = run.run_old(config.old_repo)
  io.println("done")

  io.print("running new Oneil ... ")
  let new_output = run.run_new(config.new_repo)
  io.println("done")

  // process the output to get the params and tests
  io.print("parsing old output ... ")
  let #(old_params, old_tests) = parse.parse_old_output(old_output)
  io.println("done")

  io.print("parsing new output ... ")
  let #(new_params, new_tests) = parse.parse_new_output(new_output)
  io.println("done")

  // compare the params and tests
  io.print("diffing params ... ")
  let diff_params =
    diff.diff_params(old_params, new_params, config.ignore_params)
  io.println("done")

  io.print("diffing tests ... ")
  let diff_tests = diff.diff_tests(old_tests, new_tests, config.ignore_tests)
  io.println("done")

  // print out the results
  let skip_unchanged = args.skip_unchanged
  case args.mode {
    All -> {
      print_params(diff_params, skip_unchanged)
      print_tests(diff_tests, skip_unchanged)
    }
    Params -> {
      print_params(diff_params, skip_unchanged)
    }
    Tests -> {
      print_tests(diff_tests, skip_unchanged)
    }
  }

  Nil
}

fn print_params(diffs: List(Diff(Param)), skip_unchanged: Bool) -> Nil {
  io.println("========== PARAMETERS ==========")
  print.print_params_diff(diffs, skip_unchanged)
  io.println("")
  print.print_diff_summary(diffs)
  io.println("")
}

fn print_tests(diffs: List(Diff(Test)), skip_unchanged: Bool) -> Nil {
  io.println("========== TESTS ==========")
  print.print_tests_diff(diffs, skip_unchanged)
  io.println("")
  print.print_diff_summary(diffs)
}
