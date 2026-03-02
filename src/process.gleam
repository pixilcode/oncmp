import gleam/float
import gleam/list
import gleam/string

pub type Param {
  Param(name: String, value: ParamValue, unit: String, description: String)
}

pub type ParamValue {
  Scalar(value: Float)
  Interval(min: Float, max: Float)
}

pub type Test {
  Test(model: String, expression: String, result: TestResult)
}

pub type TestResult {
  Pass
  Fail(params: List(String))
}

pub fn process_old_output(output: String) -> #(List(Param), List(Test)) {
  let output_lines = output |> string.split(on: "\n")

  let params =
    output_lines
    |> list.filter(fn(line) { line |> string.contains("-- \"") })
    |> list.map(parse_old_param)

  todo as "process old output and return params and tests"
}

fn parse_old_param(line: String) -> Param {
  let assert Ok(#(name, rest)) = line |> string.split_once(on: ":")
  let name = name |> string.trim()

  let assert Ok(#(value, rest)) =
    rest |> string.trim_start() |> string.split_once(on: " ")

  let value = parse_param_value(value)

  let assert Ok(#(unit, rest)) = rest |> string.split_once(on: "-- \"")
  let unit = unit |> string.trim()

  let assert Ok(#(description, _rest)) = rest |> string.split_once(on: "\"")
  let description = description |> string.trim()

  Param(name: name, value: value, unit: unit, description: description)
}

const divider_line = "────────────────────────────────────────────────────────────────────────────────\n"

pub fn process_new_output(output: String) -> #(List(Param), List(Test)) {
  let output = output |> string.replace(each: divider_line, with: "")
  let output_lines = output |> string.split(on: "\n")

  let params =
    output_lines
    |> list.filter(fn(line) { line |> string.contains("#") })
    |> list.map(parse_new_param)

  todo as "process new output and return params and tests"
}

fn parse_new_param(line: String) -> Param {
  let assert Ok(#(name, rest)) = line |> string.split_once(on: "=")
  let name = name |> string.trim()

  let assert Ok(#(value, rest)) = rest |> string.split_once(on: ":")
  let value = parse_param_value(value)

  let assert Ok(#(unit, description)) = rest |> string.split_once(on: "#")
  let unit = unit |> string.trim()
  let description = description |> string.trim()

  Param(name: name, value: value, unit: unit, description: description)
}

fn parse_param_value(value: String) -> ParamValue {
  let try_interval = value |> string.split_once(on: "|")

  case try_interval {
    Ok(#(min, max)) -> {
      let assert Ok(min) = min |> string.trim() |> float.parse()
      let assert Ok(max) = max |> string.trim() |> float.parse()
      Interval(min: min, max: max)
    }
    Error(Nil) -> {
      let assert Ok(value) = value |> string.trim() |> float.parse()
      Scalar(value: value)
    }
  }
}
