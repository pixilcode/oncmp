import core/config
import core/diff.{type Diff}
import core/load_output_actor
import core/parse.{type Param, type Test}
import core/run
import gleam/option.{type Option}
import gleam/otp/actor
import gleam/result
import gleam/string

pub type Context {
  Context(log: fn(String) -> Nil, config_loc: Option(String))
}

pub type Output {
  Output(param_diffs: List(Diff(Param)), test_diffs: List(Diff(Test)))
}

pub type Error {
  ConfigError(error: config.Error)
  ActorError(error: String)
  RunError(error: run.Error)
  ParseError(error: parse.Error, source: String)
}

pub fn run(context: Context) -> Result(Output, Error) {
  let log = fn(s: String) { context.log("[main] " <> s) }

  log("loading config")
  use config <- result.try(
    config.load(context.config_loc)
    |> result.map_error(ConfigError),
  )
  log("loaded config")

  let load_output_context = load_output_actor.Context(log_fn: context.log)

  // initialize the "run and parse" actors for old and new Oneil
  log("initializing actors")
  let old_actor_result =
    actor.new(load_output_actor.Uninitialized)
    |> actor.on_message(load_output_actor.handle_message(
      "old",
      run.run_old,
      parse.parse_old_output,
      load_output_context,
    ))
    |> actor.start
    |> result.map_error(fn(error) {
      ActorError(error: actor_start_error_to_string(error))
    })

  use old_actor <- result.try(old_actor_result)

  let new_actor_result =
    actor.new(load_output_actor.Uninitialized)
    |> actor.on_message(load_output_actor.handle_message(
      "new",
      run.run_new,
      parse.parse_new_output,
      load_output_context,
    ))
    |> actor.start
    |> result.map_error(fn(error) {
      ActorError(error: actor_start_error_to_string(error))
    })

  use new_actor <- result.try(new_actor_result)
  log("actors initialized")

  // run the actors
  log("running actors")
  actor.send(
    old_actor.data,
    load_output_actor.Run(config.old_repo, config.model_file),
  )

  actor.send(
    new_actor.data,
    load_output_actor.Run(config.new_repo, config.model_file),
  )

  // get the results
  let old_actor_output =
    actor.call(
      old_actor.data,
      waiting: 1_000_000,
      sending: load_output_actor.GetResult,
    )
    |> result.map_error(load_output_error_to_error)

  use #(old_params, old_tests) <- result.try(old_actor_output)

  let new_actor_output =
    actor.call(
      new_actor.data,
      waiting: 1_000_000,
      sending: load_output_actor.GetResult,
    )
    |> result.map_error(load_output_error_to_error)

  use #(new_params, new_tests) <- result.try(new_actor_output)
  log("actors completed")

  // compare the params and tests
  log("running diffs")
  let params_diff =
    diff.diff_params(old_params, new_params, config.ignore_params)

  let tests_diff = diff.diff_tests(old_tests, new_tests, config.ignore_tests)
  log("finished diffs")

  Ok(Output(params_diff, tests_diff))
}

pub fn error_to_string(
  error: Error,
  print_source_on_parse_error: Bool,
) -> String {
  case error {
    ConfigError(error:) -> config.error_to_string(error)
    ActorError(error:) -> error
    RunError(error:) -> run.error_to_string(error)
    ParseError(error:, source:) ->
      load_output_actor.error_to_string(
        load_output_actor.ParseError(error:, source:),
        print_source_on_parse_error,
      )
  }
}

fn load_output_error_to_error(error: load_output_actor.Error) -> Error {
  case error {
    load_output_actor.RunError(error:) -> RunError(error:)
    load_output_actor.ParseError(error:, source:) -> ParseError(error:, source:)
  }
}

fn actor_start_error_to_string(error: actor.StartError) -> String {
  case error {
    actor.InitTimeout -> "actor initialization timed out"
    actor.InitFailed(message) -> "actor initialization failed: " <> message
    actor.InitExited(reason) ->
      "actor initialization exited: " <> string.inspect(reason)
  }
}
