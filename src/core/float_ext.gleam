import gleam/bool
import gleam/float
import gleam/int
import gleam/result
import gleam/string

pub type FloatExt {
  Float(value: Float)
  NegativeInf
  PositiveInf
}

pub fn to_float(value: FloatExt) -> Result(Float, Nil) {
  case value {
    Float(value) -> Ok(value)
    NegativeInf | PositiveInf -> Error(Nil)
  }
}

pub fn from_float(value: Float) -> FloatExt {
  Float(value:)
}

pub fn to_string(value: FloatExt) -> String {
  case value {
    Float(value:) -> float.to_string(value)
    NegativeInf -> "-inf"
    PositiveInf -> "inf"
  }
}

pub fn parse(s: String) -> Result(FloatExt, Nil) {
  let s = string.trim(s)

  use <- bool.guard(when: s == "-inf", return: Ok(NegativeInf))
  use <- bool.guard(when: s == "inf", return: Ok(PositiveInf))

  let has_e = s |> string.contains("e")
  let has_decimal = s |> string.contains(".")

  let s = case has_e && !has_decimal {
    True -> {
      s |> string.replace(each: "e", with: ".0e")
    }
    False -> s
  }

  s
  |> float.parse()
  |> result.lazy_or(fn() {
    s
    |> int.parse()
    |> result.map(int.to_float)
  })
  |> result.map(Float)
}
