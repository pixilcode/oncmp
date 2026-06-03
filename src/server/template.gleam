import core/config
import core/diff.{type Diff, Different, NewOnly, OldOnly, Same}
import core/main
import core/parse.{
  type Param, type ParamValue, type Test, type TestDependencyParam,
  EmptyInterval, Fail, Interval, Pass, Scalar, String,
}
import core/run
import gleam/float
import gleam/int
import gleam/list
import gleam/order
import gleam/string
import server/style

pub type Config {
  Config(
    show_params_default: Bool,
    show_tests_default: Bool,
    show_unchanged_default: Bool,
    show_error_source_default: Bool,
  )
}

pub fn page(output: Result(main.Output, main.Error), config: Config) -> String {
  let body = body_from(output, config)

  "
  <!DOCTYPE html>
  <html lang=\"en\">
    <head>
    " <> head <> "
    </head>
    <body>
    " <> body <> "
    </body>
  </html>
  "
}

const head = "
  <meta charset=\"utf-8\">
  <meta name=\"viewport\" content=\"width=device-width, initial-scale=1\">
  <title>oncmp</title>
  <link rel=\"preconnect\" href=\"https://fonts.googleapis.com\">
  <link rel=\"preconnect\" href=\"https://fonts.gstatic.com\" crossorigin>
  <link href=\"https://fonts.googleapis.com/css2?family=Fira+Mono:wght@400;500;700&display=swap\" rel=\"stylesheet\">
  <style>
  "
  <> style.styles
  <> "
  </style>
  "

fn body_from(
  output: Result(main.Output, main.Error),
  config: Config,
) -> String {
  let main_sections = case output {
    Ok(output) -> output_to_html(output, config)
    Error(error) -> error_to_html(error, config)
  }

  "
  <h1>oncmp</h1>
  <main>
  " <> main_sections <> "
  </main>
  "
}

fn output_to_html(output: main.Output, config: Config) -> String {
  output_controls_section(config) <> "
  <section class=\"params\">
    <h2>Parameters</h2>
  " <> params_diff_to_html(output.param_diffs) <> "
  </section>
  <section class=\"tests\">
    <h2>Tests</h2>
  " <> tests_diff_to_html(output.test_diffs) <> "
  </section>
  "
}

fn output_controls_section(config: Config) {
  "
  <section class=\"controls\">
    " <> checkbox("Show Parameters", config.show_params_default) <> "
    " <> checkbox("Show Tests", config.show_tests_default) <> "
    " <> checkbox("Show Unchanged", config.show_unchanged_default) <> "
  </section>
  "
}

fn params_diff_to_html(diffs: List(Diff(Param))) -> String {
  diffs
  |> diff_section_to_html(param_compare, param_to_string)
}

fn tests_diff_to_html(diffs: List(Diff(Test))) -> String {
  diffs
  |> diff_section_to_html(test_compare, test_to_string)
}

fn diff_section_to_html(
  diffs: List(Diff(a)),
  compare: fn(Diff(a), Diff(a)) -> order.Order,
  to_string: fn(a) -> String,
) -> String {
  let visible_diffs =
    diffs
    |> list.sort(by: compare)

  let items =
    visible_diffs
    |> list.map(fn(diff) { diff_to_html(diff, to_string) })
    |> string.join(with: "")

  "
  <ul class=\"diff-list\">
  " <> items <> "
  </ul>
  " <> diff_summary_to_html(diffs) <> "
  "
}

fn diff_to_html(diff: Diff(a), to_string: fn(a) -> String) -> String {
  let #(class, contents) = case diff {
    OldOnly(a) -> #("removed", individual_diff_html(RemoveKind, a, to_string))
    NewOnly(a) -> #("added", individual_diff_html(AddKind, a, to_string))
    Different(old_a, new_a) -> #(
      "changed",
      individual_diff_html(RemoveKind, old_a, to_string)
        <> individual_diff_html(AddKind, new_a, to_string),
    )
    Same(a) -> #("unchanged", individual_diff_html(SameKind, a, to_string))
  }

  "<li class=\"diff " <> class <> "\">" <> contents <> "</li>"
}

type DiffKind {
  AddKind
  RemoveKind
  SameKind
}

fn individual_diff_html(
  kind: DiffKind,
  item: a,
  to_string: fn(a) -> String,
) -> String {
  let #(class, indicator) = case kind {
    AddKind -> #("add", "+")
    RemoveKind -> #("remove", "-")
    SameKind -> #("same", " ")
  }

  let indicator_html =
    "<span class=\"" <> class <> " indicator\">" <> indicator <> "</span>"

  let content = item |> to_string |> escape_html
  let content_html =
    "<pre class=\"" <> class <> " content\">" <> content <> "</pre>"

  indicator_html <> content_html
}

type DiffSummary {
  DiffSummary(added: Int, removed: Int, changed: Int)
}

fn diff_summary_to_html(diffs: List(Diff(a))) -> String {
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

  "<p class=\"summary\">"
  <> int.to_string(added)
  <> " added, "
  <> int.to_string(removed)
  <> " removed, "
  <> int.to_string(changed)
  <> " changed</p>"
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
    Pass -> #("result: pass", [])
    Fail(params) -> #(
      "result: fail",
      params
        |> list.sort(by: fn(param1, param2) {
          string.compare(param1.name, param2.name)
        })
        |> list.map(test_dependency_param_to_string),
    )
  }

  [
    main_line,
    "  " <> result_line,
    ..list.map(params_lines, fn(line) { "  " <> line })
  ]
  |> string.join(with: "\n")
}

fn test_dependency_param_to_string(param: TestDependencyParam) -> String {
  let value = value_to_string(param.value)
  let unit = case param.unit {
    Ok(unit) -> " :" <> unit
    Error(Nil) -> ""
  }

  "- " <> param.name <> " = " <> value <> unit
}

fn value_to_string(value: ParamValue) -> String {
  case value {
    Scalar(value) -> float.to_string(value)
    EmptyInterval -> "<empty>"
    Interval(min, max) -> float.to_string(min) <> " | " <> float.to_string(max)
    String(value) -> "'" <> value <> "'"
  }
}

fn error_to_html(error: main.Error, config: Config) -> String {
  let error_str = case error {
    main.ConfigError(error:) -> config.error_to_string(error)
    main.ActorError(error:) -> error
    main.RunError(error:) -> run.error_to_string(error)
    main.ParseError(error:, source: _) -> parse.error_to_string(error)
  }

  let #(maybe_controls_section, maybe_source_element) = case error {
    main.ParseError(error: _, source:) -> #(
      error_controls_section(config),
      "<pre class=\"source\">" <> escape_html(source) <> "</pre>",
    )
    _ -> #("", "")
  }

  maybe_controls_section <> "
  <section class=\"error\">
    <p class=\"message\">
      " <> error_str <> "
    </p>
    " <> maybe_source_element <> "
  </section>
  "
}

fn error_controls_section(config: Config) {
  "
  <section class=\"controls\">
    " <> checkbox("Show Source", config.show_error_source_default) <> "
  </section>
  "
}

fn checkbox(name: String, checked: Bool) -> String {
  let class =
    name
    |> string.trim
    |> string.lowercase()
    |> string.replace(each: " ", with: "-")

  let input_name = class <> "-input"

  let checked_attr = case checked {
    True -> "checked"
    False -> ""
  }

  "
  <div class=\"" <> class <> "\">
    <input type=\"checkbox\" id=\"" <> input_name <> "\" name=\"" <> input_name <> "\" " <> checked_attr <> " />
    <label for=\"" <> input_name <> "\">" <> name <> "</label>
  </div>
  "
}

fn escape_html(text: String) -> String {
  text
  |> string.replace(each: "&", with: "&amp;")
  |> string.replace(each: "<", with: "&lt;")
  |> string.replace(each: ">", with: "&gt;")
  |> string.replace(each: "\"", with: "&quot;")
}
