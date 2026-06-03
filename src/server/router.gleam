import core/main
import gleam/list
import gleam/option.{type Option}
import gleam/result
import gleam/string
import server/template
import server/web
import wisp.{type Request, type Response}

pub type RouterContext {
  Context(config_loc: Option(String))
}

pub fn handle_request(
  req: Request,
  config_loc: Option(String),
  template_config: template.Config,
) -> Response {
  use req <- web.middleware(req)

  let template_config = update_template_config_from_req(template_config, req)

  // run the diff algorithm
  let context = main.Context(log: wisp.log_info, config_loc:)
  let result = main.run(context)

  let page_html = template.page(result, template_config)
  wisp.html_response(page_html, 200)
}

fn update_template_config_from_req(
  template_config: template.Config,
  req: Request,
) -> template.Config {
  let query_params = req |> wisp.get_query

  let show_params_default =
    param_or_default(
      query_params,
      "show_params",
      template_config.show_params_default,
    )

  let show_tests_default =
    param_or_default(
      query_params,
      "show_tests",
      template_config.show_tests_default,
    )

  let show_unchanged_default =
    param_or_default(
      query_params,
      "show_unchanged",
      template_config.show_unchanged_default,
    )

  let show_error_source_default =
    param_or_default(
      query_params,
      "show_error_source",
      template_config.show_error_source_default,
    )

  template.Config(
    show_params_default:,
    show_tests_default:,
    show_unchanged_default:,
    show_error_source_default:,
  )
}

fn param_or_default(
  query_params: List(#(String, String)),
  param: String,
  default: Bool,
) -> Bool {
  query_params
  |> list.key_find(param)
  |> result.map(fn(param_value) {
    case param_value |> string.lowercase {
      "true" | "t" -> True
      _ -> False
    }
  })
  |> result.unwrap(default)
}
