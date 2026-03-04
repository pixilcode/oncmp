import gleam/int
import gleam/string

import shellout

pub fn run_old(old_repo: String, model_file: String) -> String {
  let command =
    "source .venv/bin/activate && "
    <> "cd "
    <> old_repo
    <> " && "
    <> "oneil regression-test "
    <> model_file

  run_command(command, old_repo)
}

pub fn run_new(new_repo: String, model_file: String) -> String {
  let command =
    "source .venv/bin/activate && "
    <> "cd "
    <> new_repo
    <> " && "
    <> "oneil eval "
    <> model_file
    <> " --print-mode all --no-header --no-test-report && "
    <> "oneil test "
    <> model_file
    <> " --no-header --recursive"

  run_command(command, new_repo)
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
        "\nFailed to run command (error code: "
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
