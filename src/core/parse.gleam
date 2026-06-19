import core/float_ext.{type FloatExt}
import gleam/bool
import gleam/int
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/result
import gleam/string

pub type Output =
  #(List(Param), List(Test))

pub type Error {
  OldParamMissingColon(line: String)
  OldParamMissingSpace(line: String, rest: String)
  OldParamMissingDoubleDash(line: String, rest: String)
  OldParamMissingQuote(line: String, rest: String)
  OldTestMissingClosingParen(line: String)
  OldTestMissingResult(line: String, rest: String)
  OldTestInvalidResult(result: String, line: String)
  NewOutputWrongSectionCount(section_count: Int)
  NewParamMissingEquals(line: String)
  NewParamMissingHash(line: String, rest: String)
  NewTestGroupMissingModelDelimiter(group: String)
  NewTestMissingResult(test_line: String)
  NewTestInvalidResult(result: String, test_line: String)
  NewTestDependencyParamMissingEquals(line: String)
  InvalidInterval(
    value: String,
    min: Result(FloatExt, Nil),
    max: Result(FloatExt, Nil),
  )
}

pub type Param {
  Param(
    name: String,
    value: ParamValue,
    unit: Result(String, Nil),
    description: String,
  )
}

pub type ParamValue {
  Scalar(value: FloatExt)
  Interval(min: FloatExt, max: FloatExt)
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

pub fn parse_old_output(output: String) -> Result(Output, Error) {
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

fn parse_old_param(line: String) -> Result(Param, Error) {
  use #(name, rest) <- result.try(
    line
    |> string.split_once(on: ":")
    |> result.map_error(fn(_error) { OldParamMissingColon(line:) }),
  )
  let name = name |> string.trim()

  use #(value, rest) <- result.try(
    rest
    |> string.trim_start()
    |> string.split_once(on: " ")
    |> result.map_error(fn(_error) { OldParamMissingSpace(line:, rest:) }),
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
    |> result.map_error(fn(_error) { OldParamMissingDoubleDash(line:, rest:) }),
  )

  let unit = case string.trim(unit) {
    "" -> Error(Nil)
    _ -> Ok(unit)
  }

  use #(description, _rest) <- result.try(
    rest
    |> string.split_once(on: "\"")
    |> result.map_error(fn(_error) { OldParamMissingQuote(line:, rest:) }),
  )

  let description = string.trim(description)

  Ok(Param(name: name, value: value, unit: unit, description: description))
}

fn parse_old_test(line: String) -> Result(Test, Error) {
  let line =
    line
    |> string.trim_start()

  use #(model, rest) <- result.try(
    line
    |> string.split_once(on: ")")
    |> result.map_error(fn(_error) { OldTestMissingClosingParen(line:) }),
  )

  let model = model |> string.trim()

  // drop the colon
  let rest = rest |> string.drop_start(1) |> string.trim_start()

  use #(expression, rest) <- result.try(
    rest
    |> string.split_once(on: "\n\tResult: ")
    |> result.map_error(fn(_error) { OldTestMissingResult(line:, rest:) }),
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
    _ -> Error(OldTestInvalidResult(result:, line:))
  })

  Ok(Test(model: model, expression: expression, result: result))
}

fn parse_old_test_dependency_param(
  line: String,
) -> Result(Option(TestDependencyParam), Error) {
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

pub fn parse_new_output(output: String) -> Result(Output, Error) {
  let sections = string.split(output, on: divider_line)

  // expect 4 sections
  //
  //     <empty>
  //     ---------------
  //     <model header>
  //     ---------------
  //     <params>
  //     ---------------
  //     <tests>
  //
  // we say 3 because that's what the user will perceive visually
  use <- bool.lazy_guard(list.length(sections) != 4, fn() {
    Error(NewOutputWrongSectionCount(
      section_count: sections |> list.length |> int.subtract(1),
    ))
  })

  let assert [_empty, _model_header, params, tests] = sections

  // try to parse the params
  use params <- result.try(
    params
    |> string.trim()
    |> string.split(on: "\n")
    |> list.map(parse_new_param)
    |> result.all(),
  )

  // try to parse the tests
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

fn parse_new_param(line: String) -> Result(Param, Error) {
  use #(name, rest) <- result.try(
    line
    |> string.split_once(on: "=")
    |> result.map_error(fn(_error) { NewParamMissingEquals(line:) }),
  )
  let name = name |> string.trim()

  use #(value_and_unit, description) <- result.try(
    rest
    |> string.split_once(on: "#")
    |> result.map_error(fn(_error) { NewParamMissingHash(line:, rest:) }),
  )

  let #(value, unit) = case value_and_unit |> string.split_once(on: ":") {
    Ok(#(value, unit)) -> #(value |> string.trim(), Ok(unit |> string.trim()))
    Error(Nil) -> #(value_and_unit |> string.trim(), Error(Nil))
  }

  use value <- result.try(value |> parse_param_value())

  let description = description |> string.trim()

  Ok(Param(name: name, value: value, unit: unit, description: description))
}

fn parse_new_test_group(group: String) -> Result(List(Test), Error) {
  use <- bool.guard(when: group |> string.is_empty(), return: Ok([]))

  use #(model, rest) <- result.try(
    group
    |> string.split_once(on: ".on\n")
    |> result.map_error(fn(_error) { NewTestGroupMissingModelDelimiter(group:) }),
  )

  let model = model |> string.trim()

  rest
  |> string.split(on: "test: ")
  // drop the first one because it's empty
  |> list.drop(1)
  |> list.map(fn(test_) { parse_new_test(model, test_) })
  |> result.all()
}

fn parse_new_test(model: String, test_: String) -> Result(Test, Error) {
  use #(expression, rest) <- result.try(
    test_
    |> string.split_once(on: "\n  Result: ")
    |> result.map_error(fn(_error) { NewTestMissingResult(test_line: test_) }),
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
    _ -> Error(NewTestInvalidResult(result:, test_line: test_))
  })

  Ok(Test(model: model, expression: expression, result: result))
}

fn parse_new_test_dependency_param(
  line: String,
) -> Result(Option(TestDependencyParam), Error) {
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
      NewTestDependencyParamMissingEquals(line:)
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

fn parse_param_value(value: String) -> Result(ParamValue, Error) {
  let try_interval = value |> string.split_once(on: "|")

  case try_interval {
    Ok(#(min, max)) -> {
      // try to parse as float, if that fails, try to
      // parse as int and convert to float
      let min = float_ext.parse(min)

      let max = float_ext.parse(max)

      case min, max {
        Ok(min), Ok(max) -> Ok(Interval(min: min, max: max))
        Error(Nil), Error(Nil) if min == max -> Ok(String(value: value))
        _, _ -> Error(InvalidInterval(value:, min:, max:))
      }
    }

    Error(Nil) -> {
      let value = value |> string.trim()
      case value {
        "<empty>" -> Ok(EmptyInterval)
        _ -> {
          case float_ext.parse(value) {
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

pub fn error_to_string(error: Error) -> String {
  case error {
    OldParamMissingColon(line:) ->
      "error splitting old param on ':' for string: " <> string.inspect(line)
    OldParamMissingSpace(line:, rest:) ->
      "error splitting old param on ' ' for string: "
      <> string.inspect(line)
      <> " (rest: "
      <> string.inspect(rest)
      <> ")"
    OldParamMissingDoubleDash(line:, rest:) ->
      "error splitting old param on ' -- \"' for string: "
      <> string.inspect(line)
      <> " (rest: "
      <> string.inspect(rest)
      <> ")"
    OldParamMissingQuote(line:, rest:) ->
      "error splitting old param on '\"' for string: "
      <> string.inspect(line)
      <> " (rest: "
      <> string.inspect(rest)
      <> ")"
    OldTestMissingClosingParen(line:) ->
      "error splitting test on ')' for string: " <> string.inspect(line)
    OldTestMissingResult(line:, rest:) ->
      "error splitting test on '\\n\\tResult: ' for string: "
      <> string.inspect(line)
      <> " (rest: "
      <> string.inspect(rest)
      <> ")"
    OldTestInvalidResult(result:, line:) ->
      "invalid test result: "
      <> result
      <> " (line: "
      <> string.inspect(line)
      <> ")"
    NewOutputWrongSectionCount(section_count:) ->
      "expected 3 sections (model header, params, tests), got "
      <> int.to_string(section_count)
    NewParamMissingEquals(line:) ->
      "error splitting param on '=' for string: " <> string.inspect(line)
    NewParamMissingHash(line:, rest:) ->
      "error splitting param on '#' for string: "
      <> string.inspect(line)
      <> " (rest: "
      <> string.inspect(rest)
      <> ")"
    NewTestGroupMissingModelDelimiter(group:) ->
      "error parsing test group for string: " <> group
    NewTestMissingResult(test_line:) ->
      "error splitting test on '\\n  Result: ' for string: "
      <> string.inspect(test_line)
    NewTestInvalidResult(result:, test_line:) ->
      "invalid test result: "
      <> result
      <> " for string: "
      <> string.inspect(test_line)
    NewTestDependencyParamMissingEquals(line:) ->
      "error splitting test dependency param on ' = ' for string: "
      <> string.inspect(line)
    InvalidInterval(value:, min:, max:) ->
      "invalid interval: "
      <> value
      <> "\n"
      <> string.inspect(min)
      <> "\n"
      <> string.inspect(max)
  }
}
