import gleam/http/request
import gleam/httpc
import gleam/option.{type Option}
import gleam/regexp
import gleam/result
import gleam/string

pub type Metadata {
  Metadata(title: Option(String), description: Option(String))
}

pub fn fetch_metadata(url: String) -> Result(Metadata, String) {
  use req <- result.try(request.to(url) |> result.replace_error("Invalid URL"))

  let req =
    req
    |> request.set_header("user-agent", "Feeder/1.0")
    |> request.set_header("accept", "text/html,application/xhtml+xml")

  case httpc.send(req) {
    Ok(resp) if resp.status >= 200 && resp.status < 300 -> {
      Ok(parse_metadata(resp.body))
    }
    Ok(resp) if resp.status >= 300 && resp.status < 400 -> {
      Error("Redirect not followed")
    }
    Ok(_resp) -> Error("Failed to fetch page")
    Error(_) -> Error("Network error")
  }
}

fn parse_metadata(html: String) -> Metadata {
  let title = extract_title(html)
  let description = extract_description(html)

  Metadata(title: title, description: description)
}

fn extract_title(html: String) -> Option(String) {
  let og_title = extract_meta_tag(html, "og:title")
  let twitter_title = extract_meta_tag(html, "twitter:title")
  let title_tag = extract_title_tag(html)

  case og_title {
    option.Some(_) -> og_title
    option.None ->
      case twitter_title {
        option.Some(_) -> twitter_title
        option.None -> title_tag
      }
  }
}

fn extract_description(html: String) -> Option(String) {
  let og_desc = extract_meta_tag(html, "og:description")
  let twitter_desc = extract_meta_tag(html, "twitter:description")
  let meta_desc = extract_meta_tag(html, "description")

  case og_desc {
    option.Some(_) -> og_desc
    option.None ->
      case twitter_desc {
        option.Some(_) -> twitter_desc
        option.None -> meta_desc
      }
  }
}

fn extract_meta_tag(html: String, property: String) -> Option(String) {
  let patterns = [
    "<meta\\s+property=\"" <> property <> "\"\\s+content=\"([^\"]+)\"",
    "<meta\\s+content=\"([^\"]+)\"\\s+property=\"" <> property <> "\"",
    "<meta\\s+name=\"" <> property <> "\"\\s+content=\"([^\"]+)\"",
    "<meta\\s+content=\"([^\"]+)\"\\s+name=\"" <> property <> "\"",
  ]

  extract_with_patterns(html, patterns)
}

fn extract_title_tag(html: String) -> Option(String) {
  let patterns = ["<title>([^<]+)</title>", "<title>\\s*([^<]+?)\\s*</title>"]

  extract_with_patterns(html, patterns)
}

fn extract_with_patterns(
  html: String,
  patterns: List(String),
) -> Option(String) {
  case patterns {
    [] -> option.None
    [pattern, ..rest] -> {
      let opts = regexp.Options(case_insensitive: True, multi_line: True)
      case regexp.compile(pattern, opts) {
        Ok(re) -> {
          case regexp.scan(re, html) {
            [match, ..] -> {
              case match.submatches {
                [option.Some(content)] -> option.Some(decode_html_entities(content))
                _ -> extract_with_patterns(html, rest)
              }
            }
            [] -> extract_with_patterns(html, rest)
          }
        }
        Error(_) -> extract_with_patterns(html, rest)
      }
    }
  }
}

fn decode_html_entities(text: String) -> String {
  text
  |> string.replace("&amp;", "&")
  |> string.replace("&lt;", "<")
  |> string.replace("&gt;", ">")
  |> string.replace("&quot;", "\"")
  |> string.replace("&#39;", "'")
  |> string.replace("&apos;", "'")
  |> string.trim()
}
