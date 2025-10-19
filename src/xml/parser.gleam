import gleam/option.{type Option}

pub type ParsedFeed {
  ParsedFeed(
    title: String,
    description: Option(String),
    posts: List(ParsedPost),
  )
}

pub type ParsedPost {
  ParsedPost(
    guid: String,
    title: String,
    link: String,
    description: Option(String),
    content: Option(String),
    published_at: Option(String),
  )
}

// Call Erlang helper to parse the feed
@external(erlang, "feed_parser_ffi", "parse_feed")
pub fn parse_feed(xml: String) -> Result(ParsedFeed, String)
