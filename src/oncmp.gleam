import args.{All, Params, Tests}
import argv
import cli/print
import core/main
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

  let context = main.Context(log: print.println, config_loc: args.config_loc)

  let result = main.run(context)

  use output <- util.try_or_return_lazy(result, fn(error) {
    error
    |> main.error_to_string(args.print_source_on_parse_error)
    |> print.print_error
  })

  // add a blank line between the logs and the results
  print.print_newline()

  // print out the results
  let include_unchanged = args.include_unchanged
  case args.mode {
    All -> {
      print.print_params(output.param_diffs, include_unchanged)
      print.print_tests(output.test_diffs, include_unchanged)
    }
    Params -> {
      print.print_params(output.param_diffs, include_unchanged)
    }
    Tests -> {
      print.print_tests(output.test_diffs, include_unchanged)
    }
  }

  // add a blank line at the end of the output
  print.print_newline()

  Nil
}
