import gleam/float
import gleam/io
import gleam/list
import gleam/result
import gleam/string

pub type Param {
  Param(
    name: String,
    value: ParamValue,
    unit: Result(String, Nil),
    description: String,
  )
}

pub type ParamValue {
  NaN
  Scalar(value: Float)
  EmptyInterval
  Interval(min: Float, max: Float)
  String(value: String)
}

pub type Test {
  Test(model: String, expression: String, result: TestResult)
}

pub type TestResult {
  Pass
  Fail(params: List(TestDependencyParam))
}

pub type TestDependencyParam {
  TestDependencyParam(name: String, value: ParamValue, unit: String)
}

pub fn process_old_output(output: String) -> #(List(Param), List(Test)) {
  let params =
    output
    |> string.split(on: "\n")
    |> list.filter(fn(line) { line |> string.contains("-- \"") })
    |> list.map(parse_old_param)

  let tests =
    output
    |> string.split(on: "\nTest (")
    // drop the first one because it's the parameters
    |> list.drop(1)
    |> list.map(parse_old_test)

  #(params, tests)
}

fn parse_old_param(line: String) -> Param {
  let assert Ok(#(name, rest)) = line |> string.split_once(on: ":")
  let name = name |> string.trim()

  let assert Ok(#(value, rest)) =
    rest |> string.trim_start() |> string.split_once(on: " ")
  let value = parse_param_value(value)

  let assert Ok(#(unit, rest)) = rest |> string.split_once(on: " -- \"")

  let unit = case string.trim(unit) {
    "" -> Error(Nil)
    _ -> Ok(unit)
  }

  let assert Ok(#(description, _rest)) = rest |> string.split_once(on: "\"")
  let description = string.trim(description)

  Param(name: name, value: value, unit: unit, description: description)
}

fn parse_old_test(line: String) -> Test {
  let line =
    line
    |> string.trim_start()

  let assert Ok(#(model, rest)) = line |> string.split_once(on: ")")
  let model = model |> string.trim()

  // drop the colon
  let rest = rest |> string.drop_start(1) |> string.trim_start()

  let assert Ok(#(expression, rest)) =
    rest |> string.split_once(on: "\n\tResult: ")
  let expression = expression |> string.trim()

  let assert Ok(#(result, rest)) = rest |> string.split_once(on: "\n")
  let result = result |> string.trim()

  let result = case result {
    "pass" -> Pass
    "fail" -> {
      let test_dependency_params =
        rest
        |> string.split(on: "\n")
        |> list.filter_map(parse_old_test_dependency_param)

      Fail(params: test_dependency_params)
    }
    _ -> panic as { "invalid test result: " <> result }
  }

  Test(model: model, expression: expression, result: result)
}

fn parse_old_test_dependency_param(
  line: String,
) -> Result(TestDependencyParam, Nil) {
  use #(name, rest) <- result.try(line |> string.split_once(on: ":"))

  let name = name |> string.trim()

  let assert Ok(#(value, unit)) = rest |> string.split_once(on: " ")
  let value = parse_param_value(value)
  let unit = unit |> string.trim()

  Ok(TestDependencyParam(name: name, value: value, unit: unit))
}

const divider_line = "────────────────────────────────────────────────────────────────────────────────\n"

pub fn process_new_output(output: String) -> #(List(Param), List(Test)) {
  let params =
    output
    |> string.split(on: "\n")
    |> list.filter(fn(line) { line |> string.contains("#") })
    |> list.map(parse_new_param)

  let tests =
    output
    |> string.split(on: divider_line)
    // drop before the first divider line and
    // the params before the second divider line
    |> list.drop(2)
    |> list.first()
    |> result.lazy_unwrap(or: fn() { panic as { "no tests found in output" } })
    |> string.split(on: "\n\n")
    |> list.flat_map(parse_new_test_group)

  #(params, tests)
}

fn parse_new_param(line: String) -> Param {
  let assert Ok(#(name, rest)) = line |> string.split_once(on: "=")
  let name = name |> string.trim()

  let assert Ok(#(value_and_unit, description)) =
    rest |> string.split_once(on: "#")

  let #(value, unit) = case value_and_unit |> string.split_once(on: ":") {
    Ok(#(value, unit)) -> #(value |> string.trim(), Ok(unit |> string.trim()))
    Error(Nil) -> #(value_and_unit |> string.trim(), Error(Nil))
  }

  let value = parse_param_value(value)

  let description = description |> string.trim()

  Param(name: name, value: value, unit: unit, description: description)
}

fn parse_new_test_group(group: String) -> List(Test) {
  let assert Ok(#(model, rest)) = group |> string.split_once(on: ".on\n")
  let model = model |> string.trim()

  rest
  |> string.split(on: "test: ")
  // drop the first one because it's empty
  |> list.drop(1)
  |> list.map(fn(test_) { parse_new_test(model, test_) })
}

fn parse_new_test(model: String, test_: String) -> Test {
  let assert Ok(#(expression, rest)) =
    test_ |> string.split_once(on: "\n  Result: ")
  let expression = expression |> string.trim()

  let assert Ok(#(result, rest)) = rest |> string.split_once(on: "\n")
  let result = result |> string.trim()

  let result = case result {
    "PASS" -> Pass
    "FAIL" -> {
      let test_dependency_params =
        rest
        |> string.split(on: "\n")
        |> list.map(parse_new_test_dependency_param)

      Fail(params: test_dependency_params)
    }
    _ -> panic as { "invalid test result: " <> result }
  }

  Test(model: model, expression: expression, result: result)
}

fn parse_new_test_dependency_param(line: String) -> TestDependencyParam {
  let line =
    line
    |> string.trim_start()
    // drop the `- ` prefix
    |> string.drop_start(2)

  let assert Ok(#(name, rest)) = line |> string.split_once(on: " = ")
  let name = name |> string.trim()

  let assert Ok(#(value, unit)) = rest |> string.split_once(on: " :")
  let value = value |> string.trim() |> parse_param_value()
  let unit = unit |> string.trim()

  TestDependencyParam(name: name, value: value, unit: unit)
}

fn parse_param_value(value: String) -> ParamValue {
  let try_interval = value |> string.split_once(on: "|")

  case try_interval {
    Ok(#(min, max)) -> {
      let min = min |> string.trim() |> float.parse()
      let max = max |> string.trim() |> float.parse()

      case min, max {
        Ok(min), Ok(max) -> Interval(min: min, max: max)
        Error(Nil), Error(Nil) if min == max -> String(value: value)
        _, _ -> panic as { "invalid interval: " <> value }
      }
    }

    Error(Nil) -> {
      let value = value |> string.trim()
      case value {
        "<empty>" -> EmptyInterval
        _ -> {
          case value |> float.parse() {
            Ok(value) -> Scalar(value: value)
            Error(Nil) -> String(value: value)
          }
        }
      }
    }
  }
}
