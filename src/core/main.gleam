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
  Context(
    log: fn(String) -> Nil,
    config_loc: Option(String),
    print_source_on_parse_error: Bool,
  )
}

pub type Output {
  Output(param_diffs: List(Diff(Param)), test_diffs: List(Diff(Test)))
}

pub fn run(context: Context) -> Result(Output, String) {
  let log = fn(s: String) { context.log("[main] " <> s) }

  log("loading config")
  let config_result = config.load(context.config_loc)

  use config <- result.try(config_result)
  log("loaded config")

  let load_output_context =
    load_output_actor.Context(
      print_source_on_parse_error: context.print_source_on_parse_error,
      log_fn: context.log,
    )

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
    |> result.map_error(actor_start_error_to_string)

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
    |> result.map_error(actor_start_error_to_string)

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
    |> result.map_error(fn(error) {
      load_output_actor.error_to_string(
        error,
        context.print_source_on_parse_error,
      )
    })

  use #(old_params, old_tests) <- result.try(old_actor_output)

  let new_actor_output =
    actor.call(
      new_actor.data,
      waiting: 1_000_000,
      sending: load_output_actor.GetResult,
    )
    |> result.map_error(fn(error) {
      load_output_actor.error_to_string(
        error,
        context.print_source_on_parse_error,
      )
    })

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

fn actor_start_error_to_string(error: actor.StartError) -> String {
  case error {
    actor.InitTimeout -> "actor initialization timed out"
    actor.InitFailed(message) -> "actor initialization failed: " <> message
    actor.InitExited(reason) ->
      "actor initialization exited: " <> string.inspect(reason)
  }
}
