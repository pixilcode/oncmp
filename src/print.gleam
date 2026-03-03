import gleam/dict.{type Dict}
import gleam/float
import gleam/io
import gleam/list
import gleam/string

import diff.{type Diff, Different, NewOnly, OldOnly, Same}
import process.{
  type Param, type ParamValue, type Test, type TestDependencyParam,
  EmptyInterval, Fail, Interval, NaN, Pass, Scalar, String,
}

const indent_amount = 2

pub fn print_params_diff(diffs: Dict(String, Diff(Param))) -> Nil {
  print_diff(diffs, param_to_string)
}

fn param_to_string(param: Param) -> String {
  let value = value_to_string(param.value)

  let unit = case param.unit {
    Ok(unit) -> " :" <> unit
    Error(Nil) -> ""
  }

  param.name <> " = " <> value <> unit <> "  # " <> param.description
}

pub fn print_tests_diff(diffs: Dict(String, Diff(Test))) -> Nil {
  print_diff(diffs, test_to_string)
}

fn test_to_string(test_: Test) -> String {
  let main_line = "test (" <> test_.model <> "): " <> test_.expression

  let #(result_line, params_lines) = case test_.result {
    Pass -> #(
      "result: pass"
        |> indent_line(indent_amount),
      [],
    )
    Fail(params) -> #(
      "result: fail"
        |> indent_line(indent_amount),
      params
        |> list.map(test_dependency_param_to_string)
        |> list.map(indent_line(_, indent_amount)),
    )
  }

  [main_line, result_line, ..params_lines] |> string.join(with: "\n")
}

fn indent_line(text: String, amount: Int) -> String {
  let indent_str = string.repeat(" ", times: amount)
  indent_str <> text
}

fn test_dependency_param_to_string(param: TestDependencyParam) -> String {
  let value = value_to_string(param.value)
  let unit = case param.unit {
    Ok(unit) -> " :" <> unit
    Error(Nil) -> ""
  }

  "- " <> param.name <> " = " <> value <> unit
}

fn print_diff(diffs: Dict(String, Diff(a)), to_string: fn(a) -> String) -> Nil {
  diffs
  |> dict.to_list()
  |> list.sort(by: fn(diff1, diff2) { string.compare(diff1.0, diff2.0) })
  |> list.each(fn(diff) {
    let #(_name, diff) = diff
    case diff {
      OldOnly(a) -> {
        to_string(a)
        |> indent_all_with_prefix(amount: indent_amount, prefix: "-")
        |> red()
        |> io.println()
      }

      Same(a) -> {
        to_string(a)
        |> indent_all_with_prefix(amount: indent_amount, prefix: "")
        |> io.println()
      }

      Different(old_a, new_a) -> {
        to_string(old_a)
        |> indent_all_with_prefix(amount: indent_amount, prefix: "-")
        |> red()
        |> io.println()

        to_string(new_a)
        |> indent_all_with_prefix(amount: indent_amount, prefix: "+")
        |> green()
        |> io.println()
      }

      NewOnly(a) -> {
        to_string(a)
        |> indent_all_with_prefix(amount: indent_amount, prefix: "+")
        |> green()
        |> io.println()
      }
    }
  })
}

fn value_to_string(value: ParamValue) -> String {
  case value {
    NaN -> "NaN"
    Scalar(value) -> float.to_string(value)
    EmptyInterval -> "<empty>"
    Interval(min, max) -> float.to_string(min) <> " | " <> float.to_string(max)
    String(value) -> "\"" <> value <> "\""
  }
}

fn indent_all_with_prefix(
  text: String,
  amount amount: Int,
  prefix prefix: String,
) -> String {
  let spaces_indent = amount - string.length(prefix)
  let spaces_indent_str = string.repeat(" ", times: spaces_indent)
  let indent_str = prefix <> spaces_indent_str

  text
  |> string.split(on: "\n")
  |> list.map(fn(line) { indent_str <> line })
  |> string.join(with: "\n")
}

fn red(text: String) -> String {
  "\u{001b}[91m" <> text <> "\u{001b}[0m"
}

fn green(text: String) -> String {
  "\u{001b}[92m" <> text <> "\u{001b}[0m"
}
