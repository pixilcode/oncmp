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

  let template_config = config_from_args(args)

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

fn config_from_args(args: args.Args) -> template.Config {
  let #(show_params_default, show_tests_default) = case args.mode {
    args.All -> #(True, True)
    args.Params -> #(True, False)
    args.Tests -> #(False, True)
  }

  let show_unchanged_default = args.include_unchanged

  let show_error_source_default = args.print_source_on_parse_error

  template.Config(
    show_params_default:,
    show_tests_default:,
    show_unchanged_default:,
    show_error_source_default:,
  )
}
