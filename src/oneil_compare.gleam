import argv
import gleam/bool
import gleam/io
import gleam/result

import args
import diff
import parse
import print
import run

pub fn main() -> Nil {
  io.print("loading args ... ")
  let parsed_args =
    argv.load().arguments
    |> args.parse_args()
    |> result.map_error(fn(error) { io.println("error: " <> error) })

  use <- bool.guard(when: parsed_args |> result.is_error(), return: Nil)
  let assert Ok(args) = parsed_args
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
  let diff_params = diff.diff_params(old_params, new_params)
  io.println("done")

  io.print("diffing tests ... ")
  let diff_tests = diff.diff_tests(old_tests, new_tests)
  io.println("done")

  // print out the results
  io.println("========== PARAMETERS ==========")
  print.print_params_diff(diff_params)
  io.println("")
  print.print_diff_summary(diff_params)
  io.println("")

  io.println("========== TESTS ==========")
  print.print_tests_diff(diff_tests)
  io.println("")
  print.print_diff_summary(diff_tests)

  Nil
}
