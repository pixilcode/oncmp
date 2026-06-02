pub fn try_or_return(
  result: Result(a, e),
  default: b,
  handle: fn(a) -> b,
) -> b {
  case result {
    Ok(value) -> handle(value)
    Error(_error) -> {
      default
    }
  }
}

pub fn try_or_return_lazy(
  result: Result(a, e),
  lazy_default: fn(e) -> b,
  handle: fn(a) -> b,
) -> b {
  case result {
    Ok(value) -> handle(value)
    Error(error) -> {
      lazy_default(error)
    }
  }
}
