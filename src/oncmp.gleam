import args
import argv
import cli/main as cli_main
import cli/print
import gleam/bool
import util

pub fn main() -> Nil {
  // load the args
  let parsed_args =
    argv.load().arguments
    |> args.parse_args()

  use args <- util.try_or_return_lazy(parsed_args, print.print_error_and_help)

  use <- bool.lazy_guard(when: args.show_help, return: fn() {
    print.print_help()
    Nil
  })

  cli_main.run(args)
}
