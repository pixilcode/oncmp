import gleam/float
import gleam/int
import gleam/io
import gleam/list
import gleam/order
import gleam/string

import diff.{type Diff, Different, NewOnly, OldOnly, Same}
import parse.{
  type Param, type ParamValue, type Test, type TestDependencyParam,
  EmptyInterval, Fail, Interval, Pass, Scalar, String,
}

const indent_amount = 2

pub fn print_error(error: String) -> Nil {
  { "\nerror: " <> error }
  |> red()
  |> io.println_error()
}

type DiffSummary {
  DiffSummary(added: Int, removed: Int, changed: Int)
}

pub fn print_diff_summary(diffs: List(Diff(a))) -> Nil {
  let DiffSummary(added, removed, changed) =
    diffs
    |> list.fold(
      from: DiffSummary(added: 0, removed: 0, changed: 0),
      with: fn(acc, diff) {
        case diff {
          OldOnly(_) -> DiffSummary(..acc, removed: acc.removed + 1)
          Same(_) -> acc
          Different(_, _) -> DiffSummary(..acc, changed: acc.changed + 1)
          NewOnly(_) -> DiffSummary(..acc, added: acc.added + 1)
        }
      },
    )

  let summary =
    bold("summary: ")
    <> int.to_string(added)
    <> " added, "
    <> int.to_string(removed)
    <> " removed, "
    <> int.to_string(changed)
    <> " changed"

  io.println(summary)

  Nil
}

pub fn print_params_diff(diffs: List(Diff(Param))) -> Nil {
  print_diff(diffs, param_compare, param_to_string)
}

fn param_compare(param1: Diff(Param), param2: Diff(Param)) -> order.Order {
  let name1 = diff.calc_from_diff(param1, fn(param) { param.name })
  let name2 = diff.calc_from_diff(param2, fn(param) { param.name })

  string.compare(name1, name2)
}

fn param_to_string(param: Param) -> String {
  let value = value_to_string(param.value)

  let unit = case param.unit {
    Ok(unit) -> " :" <> unit
    Error(Nil) -> ""
  }

  param.name <> " = " <> value <> unit <> "  # " <> param.description
}

pub fn print_tests_diff(diffs: List(Diff(Test))) -> Nil {
  print_diff(diffs, test_compare, test_to_string)
}

fn test_compare(test1: Diff(Test), test2: Diff(Test)) -> order.Order {
  let model1 = diff.calc_from_diff(test1, fn(test_) { test_.model })
  let model2 = diff.calc_from_diff(test2, fn(test_) { test_.model })
  let expression1 = diff.calc_from_diff(test1, fn(test_) { test_.expression })
  let expression2 = diff.calc_from_diff(test2, fn(test_) { test_.expression })

  string.compare(model1, model2)
  |> order.lazy_break_tie(fn() { string.compare(expression1, expression2) })
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
        |> list.sort(by: fn(param1, param2) {
          string.compare(param1.name, param2.name)
        })
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

fn print_diff(
  diffs: List(Diff(a)),
  compare: fn(Diff(a), Diff(a)) -> order.Order,
  to_string: fn(a) -> String,
) -> Nil {
  diffs
  |> list.sort(by: fn(diff1, diff2) { compare(diff1, diff2) })
  |> list.each(fn(diff) {
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

fn bold(text: String) -> String {
  "\u{001b}[1m" <> text <> "\u{001b}[0m"
}
