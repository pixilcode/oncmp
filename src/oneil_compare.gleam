import gleam/io

import compare
import print
import process
import run

pub fn main() -> Nil {
  // get the output from running the old and new versions of Oneil
  io.print("running old Oneil ... ")
  let old_output = run.run_old()
  io.println("done")

  io.print("running new Oneil ... ")
  let new_output = run.run_new()
  io.println("done")

  // process the output to get the params and tests
  io.print("processing old output ... ")
  let #(old_params, old_tests) = process.process_old_output(old_output)
  io.println("done")

  io.print("processing new output ... ")
  let #(new_params, new_tests) = process.process_new_output(new_output)
  io.println("done")

  // compare the params and tests
  io.print("comparing params ... ")
  let diff_params = compare.compare_params(old_params, new_params)
  io.println("done")

  io.print("comparing tests ... ")
  let diff_tests = compare.compare_tests(old_tests, new_tests)
  io.println("done")

  // print out the results
  print.print_diff("params", diff_params)
  print.print_diff("tests", diff_tests)

  Nil
}
