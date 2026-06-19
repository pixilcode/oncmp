import gleam/int
import gleam/result
import gleam/string

import shellout

pub type Error {
  RunError(error_code: Int, output: String, command: String, location: String)
}

pub fn run_old(old_repo: String, model_file: String) -> Result(String, Error) {
  let command =
    "cd "
    <> old_repo
    <> " && "
    <> "source .venv/bin/activate && "
    <> "cd model/ &&"
    <> "oneil regression-test "
    <> model_file

  run_command(command, old_repo)
}

pub fn run_new(new_repo: String, model_file: String) -> Result(String, Error) {
  let command =
    "cd "
    <> new_repo
    <> " && "
    <> "source .venv/bin/activate && "
    <> "cd model/ && "
    <> "oneil eval "
    <> model_file
    <> " --print all --cache-overwrite always && "
    <> "oneil test "
    <> model_file
    <> " --recursive --cache-overwrite always "

  run_command(command, new_repo)
}

fn run_command(command: String, location: String) -> Result(String, Error) {
  shellout.command(
    run: "sh",
    with: [
      "-c",
      command,
    ],
    in: location,
    opt: [],
  )
  |> result.map(fn(output) {
    output
    |> string.replace(each: "\u{001b}[0m", with: "")
    |> string.replace(each: "\u{001b}[91m", with: "")
    |> string.replace(each: "\u{001b}[92m", with: "")
  })
  |> result.map_error(fn(error) {
    let #(error_code, output) = error

    RunError(error_code:, output:, command:, location:)
  })
}

pub fn error_to_string(error: Error) -> String {
  "\nFailed to run command (error code: "
  <> int.to_string(error.error_code)
  <> "):\n"
  <> error.output
  <> "\n"
  <> "Command: "
  <> error.command
  <> "\n"
  <> "Location: "
  <> error.location
  <> "\n"
}
