import args
import gleam/erlang/process
import mist
import server/router
import server/template
import wisp
import wisp/wisp_mist

pub fn run(args: args.Args) {
  wisp.configure_logger()

  let secret_key_base = wisp.random_string(64)

  let template_config =
    template.Config(
      show_params_default: True,
      show_tests_default: True,
      show_unchanged_default: False,
      show_error_source_default: False,
    )

  let assert Ok(_) =
    wisp_mist.handler(
      router.handle_request(_, args.config_loc, template_config),
      secret_key_base,
    )
    |> mist.new
    |> mist.port(8000)
    |> mist.start

  process.sleep_forever()
}
