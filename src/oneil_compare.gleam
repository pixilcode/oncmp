import argv
import gleam/bool
import gleam/io
import gleam/option
import gleam/result

import args.{All, Params, Tests}
import config
import diff.{type Diff}
import parse.{type Param, type Test}
import print
import run

pub fn main() -> Nil {
  io.print("loading args ... ")
  let parsed_args =
    argv.load().arguments
    |> args.parse_args()
    |> result.map_error(print.print_error)

  use <- bool.guard(when: parsed_args |> result.is_error(), return: Nil)
  let assert Ok(args) = parsed_args
  io.println("done")

  io.print("loading config ... ")
  let config =
    config.load(args.config_loc)
    |> result.map_error(print.print_error)

  use <- bool.guard(when: config |> result.is_error(), return: Nil)
  let assert Ok(config) = config
  io.println("done")

  // get the output from running the old and new versions of Oneil
  io.print("running old Oneil ... ")
  let old_output = run.run_old()
  io.println("done")

  io.print("running new Oneil ... ")
  let new_output = run.run_new()
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
  let ignore_params =
    config
    |> option.map(fn(config) { config.ignore_params })
    |> option.unwrap(or: [])

  let diff_params = diff.diff_params(old_params, new_params, ignore_params)
  io.println("done")

  io.print("diffing tests ... ")
  let ignore_tests =
    config
    |> option.map(fn(config) { config.ignore_tests })
    |> option.unwrap(or: [])

  let diff_tests = diff.diff_tests(old_tests, new_tests, ignore_tests)
  io.println("done")

  // print out the results
  case args.mode {
    All -> {
      print_params(diff_params)
      print_tests(diff_tests)
    }
    Params -> {
      print_params(diff_params)
    }
    Tests -> {
      print_tests(diff_tests)
    }
  }

  Nil
}

fn print_params(diffs: List(Diff(Param))) -> Nil {
  io.println("========== PARAMETERS ==========")
  print.print_params_diff(diffs)
  io.println("")
  print.print_diff_summary(diffs)
  io.println("")
}

fn print_tests(diffs: List(Diff(Test))) -> Nil {
  io.println("========== TESTS ==========")
  print.print_tests_diff(diffs)
  io.println("")
  print.print_diff_summary(diffs)
}
