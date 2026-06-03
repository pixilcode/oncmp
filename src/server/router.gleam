import core/main
import gleam/option.{type Option}
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
  use _req <- web.middleware(req)

  // run the diff algorithm
  let context = main.Context(log: wisp.log_info, config_loc:)
  let result = main.run(context)

  let page_html = template.page(result, template_config)
  wisp.html_response(page_html, 200)
}
