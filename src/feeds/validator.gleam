import feeds/feed.{type FeedError}
import gleam/string
import gleam/uri

/// Validates the URL of a feed.
pub fn validate_url(url: String) -> Result(Nil, FeedError) {
  case string.trim(url) {
    "" -> Error(feed.InvalidUrl("URL cannot be empty"))
    trimmed_url -> {
      case
        string.starts_with(trimmed_url, "http://")
        || string.starts_with(trimmed_url, "https://")
      {
        True -> {
          case uri.parse(trimmed_url) {
            Ok(_) -> Ok(Nil)
            Error(_) -> Error(feed.InvalidUrl("Malformed URL"))
          }
        }
        False ->
          Error(feed.InvalidUrl("URL must start with http:// or https://"))
      }
    }
  }
}

/// Validates the title of a feed.
pub fn validate_title(title: String) -> Result(Nil, FeedError) {
  let trimmed = string.trim(title)
  case string.length(trimmed) {
    0 -> Error(feed.InvalidUrl("Title cannot be empty"))
    len if len > 200 ->
      Error(feed.InvalidUrl("Title too long (max 200 characters)"))
    _ -> Ok(Nil)
  }
}

/// Validates description length of a feed.
pub fn validate_description(description: String) -> Result(Nil, FeedError) {
  case string.length(description) {
    len if len > 1000 ->
      Error(feed.InvalidUrl("Description too long (max 1000 characters)"))
    _ -> Ok(Nil)
  }
}

