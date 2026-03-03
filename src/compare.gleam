import gleam/dict.{type Dict}
import gleam/list

import process.{type Param, type Test}

pub type Diff(a) {
  OldOnly(a)
  Same(a)
  Different(a, a)
  NewOnly(a)
}

pub fn compare_params(
  old_params: List(Param),
  new_params: List(Param),
) -> Dict(String, Diff(Param)) {
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
}

fn params_equal(old_param: Param, new_param: Param) -> Bool {
  old_param.name == new_param.name
  && old_param.value == new_param.value
  && old_param.unit == new_param.unit
  && old_param.description == new_param.description
}

pub fn compare_tests(
  old_tests: List(Test),
  new_tests: List(Test),
) -> Dict(String, Diff(Test)) {
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
}

fn tests_equal(old_test: Test, new_test: Test) -> Bool {
  old_test.model == new_test.model
  && old_test.expression == new_test.expression
  && old_test.result == new_test.result
}
