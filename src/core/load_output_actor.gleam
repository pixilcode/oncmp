import core/parse.{type ParseOutput}
import core/run
import gleam/bool
import gleam/erlang/process.{type Subject}
import gleam/otp/actor
import gleam/result
import gleam/string

pub type LoadOutputContext {
  Context(print_source_on_parse_error: Bool, log_fn: fn(String) -> Nil)
}

pub type LoadOutputState {
  Uninitialized
  Complete(Result(ParseOutput, String))
}

pub type LoadOutputMessage {
  Run(repo: String, model_file: String)
  GetResult(Subject(Result(ParseOutput, String)))
}

pub fn handle_message(
  name: String,
  run_fn: fn(String, String) -> Result(String, run.Error),
  parse_fn: fn(String) -> Result(ParseOutput, String),
  context: LoadOutputContext,
) -> fn(LoadOutputState, LoadOutputMessage) ->
  actor.Next(LoadOutputState, LoadOutputMessage) {
  let log = fn(name: String, message: String) {
    context.log_fn("  [" <> name <> "] " <> message)
  }

  fn(state, message) {
    case state, message {
      Uninitialized, Run(repo, model_file) -> {
        let result: Result(ParseOutput, String) = {
          // run the program
          log(name, "running program")
          let output_result =
            run_fn(repo, model_file)
            |> result.map_error(run.error_to_string)
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
            use <- bool.guard(!context.print_source_on_parse_error, error)

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
