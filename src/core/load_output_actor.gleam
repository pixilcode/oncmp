import core/parse
import core/run
import gleam/bool
import gleam/erlang/process.{type Subject}
import gleam/otp/actor
import gleam/result
import gleam/string

pub type Context {
  Context(print_source_on_parse_error: Bool, log_fn: fn(String) -> Nil)
}

pub type State {
  Uninitialized
  Complete(Result(parse.Output, Error))
}

pub type Message {
  Run(repo: String, model_file: String)
  GetResult(Subject(Result(parse.Output, Error)))
}

pub type Error {
  RunError(error: run.Error)
  ParseError(error: parse.Error, source: String)
}

pub fn handle_message(
  name: String,
  run_fn: fn(String, String) -> Result(String, run.Error),
  parse_fn: fn(String) -> Result(parse.Output, parse.Error),
  context: Context,
) -> fn(State, Message) -> actor.Next(State, Message) {
  let log = fn(name: String, message: String) {
    context.log_fn("  [" <> name <> "] " <> message)
  }

  fn(state, message) {
    case state, message {
      Uninitialized, Run(repo, model_file) -> {
        let result: Result(parse.Output, Error) = {
          // run the program
          log(name, "running program")
          let output_result =
            run_fn(repo, model_file)
            |> result.map_error(fn(error) {
              log(name, "running program failed")
              RunError(error:)
            })
          log(name, "received program result")

          // if running the program failed, return early
          use output <- result.try(output_result)

          log(name, "parsing program output")
          let parse_result =
            parse_fn(output)
            |> result.map_error(fn(error) {
              log(name, "parsing program output failed")
              ParseError(error:, source: output)
            })
          log(name, "parsed program output")

          parse_result
        }

        actor.continue(Complete(result))
      }

      Complete(result), GetResult(reply) -> {
        actor.send(reply, result)
        actor.stop()
      }
      _, _ -> panic as "invalid message and state"
    }
  }
}

pub fn error_to_string(
  error: Error,
  print_source_on_parse_error: Bool,
) -> String {
  case error {
    RunError(error:) -> run.error_to_string(error)
    ParseError(error:, source:) -> {
      let message = parse.error_to_string(error)

      use <- bool.guard(!print_source_on_parse_error, message)

      let source = source |> string.replace(each: "\n", with: "\n    ")
      message <> "\n\nSource:\n    " <> source
    }
  }
}
