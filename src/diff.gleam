import gleam/bool
import gleam/dict
import gleam/float
import gleam/list
import gleam/result

import parse.{
  type Param, type ParamValue, type Test, type TestDependencyParam,
  type TestResult, EmptyInterval, Fail, Interval, Pass, Scalar, String,
}

pub type Diff(a) {
  OldOnly(a)
  Same(a)
  Different(a, a)
  NewOnly(a)
}

pub fn calc_from_diff(diff: Diff(a), f: fn(a) -> b) -> b {
  let a = case diff {
    OldOnly(a) -> a
    Same(a) -> a
    Different(a, _) -> a
    NewOnly(a) -> a
  }

  f(a)
}

pub fn diff_params(
  old_params: List(Param),
  new_params: List(Param),
) -> List(Diff(Param)) {
  let old_params_dict =
    old_params
    |> list.map(fn(param) { #(param.name, param) })
    |> dict.from_list()
    |> dict.map_values(fn(_name, param) { OldOnly(param) })

  let new_params_dict =
    new_params
    |> list.map(fn(param) { #(param.name, param) })
    |> dict.from_list()
    |> dict.map_values(fn(_name, param) { NewOnly(param) })

  old_params_dict
  |> dict.combine(new_params_dict, with: fn(old_param, new_param) {
    let assert OldOnly(old_param) = old_param
    let assert NewOnly(new_param) = new_param

    case params_equal(old_param, new_param) {
      True -> Same(old_param)
      False -> Different(old_param, new_param)
    }
  })
  |> dict.values()
}

fn params_equal(old_param: Param, new_param: Param) -> Bool {
  old_param.name == new_param.name
  && value_is_close(old_param.value, new_param.value)
  && old_param.unit == new_param.unit
  && old_param.description == new_param.description
}

pub fn diff_tests(
  old_tests: List(Test),
  new_tests: List(Test),
) -> List(Diff(Test)) {
  let old_tests_dict =
    old_tests
    |> list.map(fn(test_) { #(test_.expression, test_) })
    |> dict.from_list()
    |> dict.map_values(fn(_name, test_) { OldOnly(test_) })

  let new_tests_dict =
    new_tests
    |> list.map(fn(test_) { #(test_.expression, test_) })
    |> dict.from_list()
    |> dict.map_values(fn(_name, test_) { NewOnly(test_) })

  old_tests_dict
  |> dict.combine(new_tests_dict, with: fn(old_test, new_test) {
    let assert OldOnly(old_test) = old_test
    let assert NewOnly(new_test) = new_test

    case tests_equal(old_test, new_test) {
      True -> Same(old_test)
      False -> Different(old_test, new_test)
    }
  })
  |> dict.values()
}

fn tests_equal(old_test: Test, new_test: Test) -> Bool {
  old_test.model == new_test.model
  && old_test.expression == new_test.expression
  && test_results_equal(old_test.result, new_test.result)
}

fn test_results_equal(old_result: TestResult, new_result: TestResult) -> Bool {
  case old_result, new_result {
    Pass, Pass -> True
    Fail(old_params), Fail(new_params) ->
      test_dependency_params_are_close(old_params, new_params)
    _, _ -> False
  }
}

fn test_dependency_params_are_close(
  old_params: List(TestDependencyParam),
  new_params: List(TestDependencyParam),
) -> Bool {
  let old_params_dict =
    old_params
    |> list.map(fn(param) { #(param.name, param) })
    |> dict.from_list()

  let old_params_dict_size = old_params_dict |> dict.size()

  let new_params_dict =
    new_params
    |> list.map(fn(param) { #(param.name, param) })
    |> dict.from_list()

  let new_params_dict_size = new_params_dict |> dict.size()

  use <- bool.guard(
    when: old_params_dict_size != new_params_dict_size,
    return: False,
  )

  old_params_dict
  |> dict.fold(from: True, with: fn(params_are_close, param_name, old_param) {
    let new_param = new_params_dict |> dict.get(param_name)

    use <- bool.guard(when: result.is_error(new_param), return: False)
    let assert Ok(new_param) = new_param

    params_are_close
    && old_param.unit == new_param.unit
    && value_is_close(old_param.value, new_param.value)
  })
}

fn value_is_close(a: ParamValue, b: ParamValue) -> Bool {
  case a, b {
    Scalar(a), Scalar(b) -> is_close(a, b)
    Interval(a_min, a_max), Interval(b_min, b_max) ->
      is_close(a_min, b_min) && is_close(a_max, b_max)
    EmptyInterval, EmptyInterval -> True
    String(a), String(b) -> a == b
    _, _ -> False
  }
}

fn is_close(a: Float, b: Float) -> Bool {
  use <- bool.guard(when: a == b, return: True)

  let assert Ok(tolerance) = float.power(10.0, -3.0)

  let difference = float.absolute_value(a -. b)

  let relative_tolerance =
    tolerance *. float.min(float.absolute_value(a), float.absolute_value(b))

  let absolute_tolerance = tolerance

  difference <=. relative_tolerance || difference <=. absolute_tolerance
}
