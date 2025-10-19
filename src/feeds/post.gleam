import gleam/option.{type Option}

pub type Post {
  Post(
    id: Option(Int),
    feed_id: Int,
    guid: String,
    title: String,
    link: String,
    description: Option(String),
    content: Option(String),
    published_at: Option(String),
    fetched_at: String,
  )
}

pub type NewPost {
  NewPost(
    feed_id: Int,
    guid: String,
    title: String,
    link: String,
    description: Option(String),
    content: Option(String),
    published_at: Option(String),
  )
}
