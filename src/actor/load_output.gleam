import gleam/bool
import gleam/erlang/process.{type Subject}
import gleam/io
import gleam/otp/actor
import gleam/result
import gleam/string

import parse.{type Param, type Test}

pub type LoadOutputState {
  Uninitialized
  Complete(Result(#(List(Param), List(Test)), String))
}

pub type LoadOutputMessage {
  Run(repo: String, model_file: String)
  GetResult(Subject(Result(#(List(Param), List(Test)), String)))
}

pub fn handle_message(
  name: String,
  run_fn: fn(String, String) -> Result(String, String),
  parse_fn: fn(String) -> Result(#(List(Param), List(Test)), String),
  print_source_on_parse_error: Bool,
) -> fn(LoadOutputState, LoadOutputMessage) ->
  actor.Next(LoadOutputState, LoadOutputMessage) {
  fn(state, message) {
    case state, message {
      Uninitialized, Run(repo, model_file) -> {
        let result: Result(#(List(Param), List(Test)), String) = {
          // run the program
          log(name, "running program")
          let output_result = run_fn(repo, model_file)
          log(name, "received program result")

          // print out an error if running the program failed
          let _ =
            output_result
            |> result.map_error(fn(_error) {
              log(name, "running program failed")
            })

          // if running the program failed, return early
          use output <- result.try(output_result)

          log(name, "parsing program output")
          let parse_result = parse_fn(output)
          log(name, "parsed program output")

          // print out an error if parsing the output failed
          let _ =
            parse_result
            |> result.map_error(fn(_error) {
              log(name, "parsing program output failed")
            })

          parse_result
          |> result.map_error(fn(error) {
            use <- bool.guard(!print_source_on_parse_error, error)

            let output = output |> string.replace(each: "\n", with: "\n    ")
            error <> "\n\nSource:\n    " <> output
          })
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

fn log(name: String, message: String) {
  io.println("  [" <> name <> "] " <> message)
}
