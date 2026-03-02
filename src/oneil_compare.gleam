import gleam/io

pub fn main() -> Nil {
  let #(old_output, new_output) = get_regression_output()

  let #(old_params, old_tests) = process_old_output(old_output)
  let #(new_params, new_tests) = process_new_output(new_output)

  let diff_params = compare_params(old_params, new_params)
  let diff_tests = compare_tests(old_tests, new_tests)

  io.println("Diff params: " <> diff_params)
  io.println("Diff tests: " <> diff_tests)

  Nil
}

fn get_regression_output() -> #(String, String) {
  let old_output = run_old_regression()
  let new_output = run_new_regression()

  #(old_output, new_output)
}

fn run_old_regression() -> String {
  todo as "run old regression test and return output"
}

fn run_new_regression() -> String {
  todo as "run new regression test and return output"
}

fn process_old_output(output: String) -> #(String, String) {
  todo as "process old output and return params and tests"
}

fn process_new_output(output: String) -> #(String, String) {
  todo as "process new output and return params and tests"
}

fn compare_params(old_params: String, new_params: String) -> String {
  todo as "compare params and return diff"
}

fn compare_tests(old_tests: String, new_tests: String) -> String {
  todo as "compare tests and return diff"
}
