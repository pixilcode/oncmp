import gleam/bool
import gleam/float
import gleam/int
import gleam/list
import gleam/option.{type Option, None, Some}
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
  Scalar(value: Float)
  Interval(min: Float, max: Float)
  EmptyInterval
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
  TestDependencyParam(
    name: String,
    value: ParamValue,
    unit: Result(String, Nil),
  )
}

pub fn parse_old_output(
  output: String,
) -> Result(#(List(Param), List(Test)), String) {
  use params <- result.try(
    output
    |> string.split(on: "\n")
    |> list.filter(fn(line) { line |> string.contains("-- \"") })
    |> list.map(parse_old_param)
    |> result.all(),
  )

  use tests <- result.try(
    output
    |> string.split(on: "\nTest (")
    // drop the first one because it's the parameters
    |> list.drop(1)
    |> list.map(parse_old_test)
    |> result.all(),
  )

  Ok(#(params, tests))
}

fn parse_old_param(line: String) -> Result(Param, String) {
  use #(name, rest) <- result.try(
    line
    |> string.split_once(on: ":")
    |> result.map_error(fn(_error) {
      "error splitting old param on ':' for string: " <> string.inspect(line)
    }),
  )
  let name = name |> string.trim()

  use #(value, rest) <- result.try(
    rest
    |> string.trim_start()
    |> string.split_once(on: " ")
    |> result.map_error(fn(_error) {
      "error splitting old param on ' ' for string: "
      <> string.inspect(line)
      <> " (rest: "
      <> string.inspect(rest)
      <> ")"
    }),
  )

  // strings are printed out as `my_str | my_str`
  // so we need to check if the value is repeated after the `|`
  use #(value, rest) <- result.try(
    rest
    |> string.split_once(on: "| " <> value)
    |> result.map(fn(result) {
      let #(_, rest) = result
      let value = String(value: value)
      #(value, rest)
    })
    |> result.try_recover(fn(_error) {
      use value <- result.try(value |> parse_param_value())
      Ok(#(value, rest))
    }),
  )

  use #(unit, rest) <- result.try(
    rest
    |> string.split_once(on: " -- \"")
    |> result.map_error(fn(_error) {
      "error splitting old param on ' -- \"' for string: "
      <> string.inspect(line)
      <> " (rest: "
      <> string.inspect(rest)
      <> ")"
    }),
  )

  let unit = case string.trim(unit) {
    "" -> Error(Nil)
    _ -> Ok(unit)
  }

  use #(description, _rest) <- result.try(
    rest
    |> string.split_once(on: "\"")
    |> result.map_error(fn(_error) {
      "error splitting old param on '\"' for string: "
      <> string.inspect(line)
      <> " (rest: "
      <> string.inspect(rest)
      <> ")"
    }),
  )

  let description = string.trim(description)

  Ok(Param(name: name, value: value, unit: unit, description: description))
}

fn parse_old_test(line: String) -> Result(Test, String) {
  let line =
    line
    |> string.trim_start()

  use #(model, rest) <- result.try(
    line
    |> string.split_once(on: ")")
    |> result.map_error(fn(_error) {
      "error splitting test on ')' for string: " <> string.inspect(line)
    }),
  )

  let model = model |> string.trim()

  // drop the colon
  let rest = rest |> string.drop_start(1) |> string.trim_start()

  use #(expression, rest) <- result.try(
    rest
    |> string.split_once(on: "\n\tResult: ")
    |> result.map_error(fn(_error) {
      "error splitting test on '\\n\\tResult: ' for string: "
      <> string.inspect(line)
      <> " (rest: "
      <> string.inspect(rest)
      <> ")"
    }),
  )

  let expression =
    expression
    |> string.trim()
    // remove the par_ prefix from Oneil functions
    |> string.replace(each: "par_", with: "")
    // replace ** with ^ for power operator
    |> string.replace(each: "**", with: "^")

  let #(result, rest) =
    rest
    |> string.split_once(on: "\n")
    |> result.unwrap(or: #(rest, ""))

  let result = result |> string.trim()

  use result <- result.try(case result {
    "pass" -> Ok(Pass)
    "fail" -> {
      use test_dependency_params <- result.try(
        rest
        |> string.split(on: "\n")
        |> list.map(parse_old_test_dependency_param)
        |> result.all(),
      )

      let test_dependency_params =
        test_dependency_params
        |> list.filter_map(fn(param) {
          param
          |> option.map(Ok)
          |> option.unwrap(or: Error(Nil))
        })

      Ok(Fail(params: test_dependency_params))
    }
    _ ->
      Error(
        "invalid test result: "
        <> result
        <> " (line: "
        <> string.inspect(line)
        <> ")",
      )
  })

  Ok(Test(model: model, expression: expression, result: result))
}

fn parse_old_test_dependency_param(
  line: String,
) -> Result(Option(TestDependencyParam), String) {
  let result =
    line
    |> string.split_once(on: ":")

  use <- bool.guard(when: result |> result.is_error(), return: Ok(None))
  let assert Ok(#(name, rest)) = result

  let name = name |> string.trim()

  let #(value, unit) = case
    rest |> string.trim_start() |> string.split_once(on: " ")
  {
    Ok(#(value, unit)) -> #(value |> string.trim(), Ok(unit |> string.trim()))
    Error(Nil) -> #(rest |> string.trim(), Error(Nil))
  }

  use value <- result.try(value |> parse_param_value())

  Ok(Some(TestDependencyParam(name: name, value: value, unit: unit)))
}

const divider_line = "────────────────────────────────────────────────────────────────────────────────\n"

pub fn parse_new_output(
  output: String,
) -> Result(#(List(Param), List(Test)), String) {
  use params <- result.try(
    output
    |> string.split(on: "\n")
    |> list.filter(fn(line) { line |> string.contains("#") })
    |> list.map(parse_new_param)
    |> result.all(),
  )

  use tests <- result.try(
    output
    |> string.split(on: divider_line)
    // drop before the first divider line and
    // the params before the second divider line
    |> list.drop(2)
    |> list.first()
    |> result.map_error(fn(_error) { "no tests found in output" }),
  )

  use tests <- result.try(
    tests
    |> string.split(on: "\n\n")
    |> list.map(parse_new_test_group)
    |> result.all(),
  )

  let tests =
    tests
    |> list.flatten()

  Ok(#(params, tests))
}

fn parse_new_param(line: String) -> Result(Param, String) {
  use #(name, rest) <- result.try(
    line
    |> string.split_once(on: "=")
    |> result.map_error(fn(_error) {
      "error splitting param on '=' for string: " <> string.inspect(line)
    }),
  )
  let name = name |> string.trim()

  use #(value_and_unit, description) <- result.try(
    rest
    |> string.split_once(on: "#")
    |> result.map_error(fn(_error) {
      "error splitting param on '#' for string: "
      <> string.inspect(line)
      <> " (rest: "
      <> string.inspect(rest)
      <> ")"
    }),
  )

  let #(value, unit) = case value_and_unit |> string.split_once(on: ":") {
    Ok(#(value, unit)) -> #(value |> string.trim(), Ok(unit |> string.trim()))
    Error(Nil) -> #(value_and_unit |> string.trim(), Error(Nil))
  }

  use value <- result.try(value |> parse_param_value())

  let description = description |> string.trim()

  Ok(Param(name: name, value: value, unit: unit, description: description))
}

fn parse_new_test_group(group: String) -> Result(List(Test), String) {
  use <- bool.guard(when: group |> string.is_empty(), return: Ok([]))

  use #(model, rest) <- result.try(
    group
    |> string.split_once(on: ".on\n")
    |> result.map_error(fn(_error) {
      "error parsing test group for string: " <> group
    }),
  )

  let model = model |> string.trim()

  rest
  |> string.split(on: "test: ")
  // drop the first one because it's empty
  |> list.drop(1)
  |> list.map(fn(test_) { parse_new_test(model, test_) })
  |> result.all()
}

fn parse_new_test(model: String, test_: String) -> Result(Test, String) {
  use #(expression, rest) <- result.try(
    test_
    |> string.split_once(on: "\n  Result: ")
    |> result.map_error(fn(_error) {
      "error splitting test on '\\n  Result: ' for string: "
      <> string.inspect(test_)
    }),
  )

  let expression = expression |> string.trim()

  let #(result, rest) =
    rest
    |> string.split_once(on: "\n")
    |> result.unwrap(or: #(rest, ""))

  let result = result |> string.trim()

  use result <- result.try(case result {
    "PASS" -> Ok(Pass)
    "FAIL" -> {
      use test_dependency_params <- result.try(
        rest
        |> string.split(on: "\n")
        |> list.map(parse_new_test_dependency_param)
        |> result.all(),
      )

      let test_dependency_params =
        test_dependency_params
        |> list.filter_map(fn(param) {
          param
          |> option.map(Ok)
          |> option.unwrap(or: Error(Nil))
        })

      Ok(Fail(params: test_dependency_params))
    }
    _ ->
      Error(
        "invalid test result: "
        <> result
        <> " for string: "
        <> string.inspect(test_),
      )
  })

  Ok(Test(model: model, expression: expression, result: result))
}

fn parse_new_test_dependency_param(
  line: String,
) -> Result(Option(TestDependencyParam), String) {
  use <- bool.guard(when: line |> string.is_empty(), return: Ok(None))

  let line =
    line
    |> string.trim_start()
    // drop the `- ` prefix
    |> string.drop_start(2)

  use #(name, rest) <- result.try(
    line
    |> string.split_once(on: " = ")
    |> result.map_error(fn(_error) {
      "error splitting test dependency param on ' = ' for string: "
      <> string.inspect(line)
    }),
  )

  let name = name |> string.trim()

  let #(value, unit) = case rest |> string.split_once(on: " :") {
    Ok(#(value, unit)) -> #(value |> string.trim(), Ok(unit |> string.trim()))
    Error(Nil) -> #(rest |> string.trim(), Error(Nil))
  }

  use value <- result.try(value |> parse_param_value())

  Ok(Some(TestDependencyParam(name: name, value: value, unit: unit)))
}

fn parse_param_value(value: String) -> Result(ParamValue, String) {
  let try_interval = value |> string.split_once(on: "|")

  case try_interval {
    Ok(#(min, max)) -> {
      // try to parse as float, if that fails, try to
      // parse as int and convert to float
      let min =
        min
        |> string.trim()
        |> parse_int_or_float()

      let max =
        max
        |> string.trim()
        |> parse_int_or_float()

      case min, max {
        Ok(min), Ok(max) -> Ok(Interval(min: min, max: max))
        Error(Nil), Error(Nil) if min == max -> Ok(String(value: value))
        _, _ ->
          Error(
            "invalid interval: "
            <> value
            <> "\n"
            <> string.inspect(min)
            <> "\n"
            <> string.inspect(max),
          )
      }
    }

    Error(Nil) -> {
      let value = value |> string.trim()
      case value {
        "<empty>" -> Ok(EmptyInterval)
        _ -> {
          case value |> parse_int_or_float() {
            Ok(value) -> Ok(Scalar(value: value))
            Error(Nil) -> Ok(String(value: parse_string(value)))
          }
        }
      }
    }
  }
}

fn parse_string(value: String) -> String {
  value
  |> string.trim()
  |> string.replace(each: "'", with: "")
}

fn parse_int_or_float(value: String) -> Result(Float, Nil) {
  let has_e = value |> string.contains("e")
  let has_decimal = value |> string.contains(".")

  let value = case has_e && !has_decimal {
    True -> {
      value |> string.replace(each: "e", with: ".0e")
    }
    False -> value
  }

  value
  |> string.trim()
  |> float.parse()
  |> result.lazy_or(fn() {
    value
    |> string.trim()
    |> int.parse()
    |> result.map(int.to_float)
  })
}
