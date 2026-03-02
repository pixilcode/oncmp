import gleam/io

pub fn print_diff(title: String, diff: String) -> Nil {
  io.println("diff " <> title <> ":")
  io.println(diff)
}
