import gleam/int
import gleam/io
import gleam/string

import shellout

pub fn main() -> Nil {
  let #(old_output, new_output) = get_regression_output()

  let #(old_params, old_tests) = process_old_output(old_output)
  let #(new_params, new_tests) = process_new_output(new_output)

  let diff_params = compare_params(old_params, new_params)
  let diff_tests = compare_tests(old_tests, new_tests)

  io.println("Diff params: " <> diff_params)
  io.println("Diff tests: " <> diff_tests)

  Nil
}

fn get_regression_output() -> #(String, String) {
  let old_output = run_old_regression()
  let new_output = run_new_regression()

  #(old_output, new_output)
}

fn run_old_regression() -> String {
  let old_location = "../veery_old"
  let command =
    "source .venv/bin/activate && "
    <> "cd model && "
    <> "oneil regression-test radar.on"

  run_command(command, old_location)
}

fn run_new_regression() -> String {
  let new_location = "../veery"

  let command =
    "source .venv/bin/activate && "
    <> "cd model && "
    <> "oneil eval radar.on --print-mode all --no-header --no-test-report && "
    <> "oneil test radar.on --no-header --recursive"

  run_command(command, new_location)
}

fn run_command(command: String, location: String) -> String {
  let result =
    shellout.command(
      run: "sh",
      with: [
        "-c",
        command,
      ],
      in: location,
      opt: [],
    )

  let output = case result {
    Ok(output) -> output
    Error(#(error_code, output)) -> {
      panic as {
        "Failed to run command (error code: "
        <> int.to_string(error_code)
        <> "):\n"
        <> output
        <> "\n"
        <> "Command: "
        <> command
        <> "\n"
        <> "Location: "
        <> location
        <> "\n"
      }
    }
  }

  // remove ANSI escape codes
  output
  |> string.replace(each: "\u{001b}[0m", with: "")
  |> string.replace(each: "\u{001b}[91m", with: "")
  |> string.replace(each: "\u{001b}[92m", with: "")
}

fn process_old_output(output: String) -> #(String, String) {
  todo as "process old output and return params and tests"
}

fn process_new_output(output: String) -> #(String, String) {
  todo as "process new output and return params and tests"
}

fn compare_params(old_params: String, new_params: String) -> String {
  todo as "compare params and return diff"
}

fn compare_tests(old_tests: String, new_tests: String) -> String {
  todo as "compare tests and return diff"
}
