import gleam/int
import gleam/string

import shellout

pub fn run_old(old_repo: String) -> String {
  let command =
    "source .venv/bin/activate && "
    <> "cd "
    <> old_repo
    <> " && "
    <> "oneil regression-test radar.on"

  run_command(command, old_repo)
}

pub fn run_new(new_repo: String) -> String {
  let command =
    "source .venv/bin/activate && "
    <> "cd "
    <> new_repo
    <> " && "
    <> "oneil eval radar.on --print-mode all --no-header --no-test-report && "
    <> "oneil test radar.on --no-header --recursive"

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
