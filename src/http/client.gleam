import gleam/http
import gleam/http/request
import gleam/httpc
import gleam/int
import gleam/result

pub fn fetch_feed(url: String) -> Result(String, String) {
  use req <- result.try(request.to(url) |> result.replace_error("Invalid URL"))

  let req =
    req
    |> request.set_header("user-agent", "Feeder/1.0")
    |> request.set_header(
      "accept",
      "application/rss+xml, application/atom+xml, text/xml",
    )

  case httpc.send(req) {
    Ok(resp) if resp.status >= 200 && resp.status < 300 -> Ok(resp.body)
    Ok(resp) -> Error("HTTP error: " <> int.to_string(resp.status))
    Error(_) -> Error("Failed to fetch feed")
  }
}

pub fn check_feed(url: String) -> Result(Nil, String) {
  use req <- result.try(request.to(url) |> result.replace_error("Invalid URL"))

  let req =
    request.set_method(req, http.Head)
    |> request.set_header("user-agent", "Feeder/1.0")

  case httpc.send(req) {
    Ok(resp) if resp.status >= 200 && resp.status < 300 -> Ok(Nil)
    Ok(resp) -> Error("HTTP error: " <> int.to_string(resp.status))
    Error(_) -> Error("Failed to reach feed")
  }
}
