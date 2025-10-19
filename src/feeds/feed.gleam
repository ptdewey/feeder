import gleam/option.{type Option}

/// System representation of an RSS/Atom feed.
pub type Feed {
  Feed(
    id: Option(Int),
    url: String,
    title: String,
    description: Option(String),
    added_at: String,
    last_checked: Option(String),
    is_active: Bool,
  )
}

pub type NewFeed {
  NewFeed(url: String, title: Option(String), description: Option(String))
}

pub type FeedError {
  InvalidUrl(String)
  FetchFailed(String)
  AlreadyExists
  NotFound
  DatabaseError(String)
}

pub type FeedMetadata {
  FeedMetadata(title: String, description: Option(String))
}
