import wisp.{type Request, type Response}

import server/web

pub fn handle_request(req: Request) -> Response {
  use _req <- web.middleware(req)

  wisp.html_response(page(), 200)
}

fn page() -> String {
  let body = todo

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
  <title>Wisp Example</title>
  <style>
  "
  <> styles
  <> "
  </style>"

const styles = ""
