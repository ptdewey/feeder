import feeds/feed.{type Feed, type FeedError, type NewFeed, Feed}
import gleam/dynamic
import gleam/dynamic/decode
import gleam/option.{type Option, None, Some}
import sqlight.{type Connection}

pub fn get_all(db: Connection) -> Result(List(Feed), FeedError) {
  let sql =
    "
    SELECT id, url, title, description, added_at, last_checked, is_active
    FROM feeds
    ORDER BY added_at DESC
    "

  case sqlight.query(sql, db, [], feed_decoder()) {
    Ok(feeds) -> Ok(feeds)
    Error(_) -> Error(feed.DatabaseError("Failed to query feeds"))
  }
}

fn feed_decoder() -> decode.Decoder(Feed) {
  {
    use id <- decode.field(0, decode.optional(decode.int))
    use url <- decode.field(1, decode.string)
    use title <- decode.field(2, decode.string)
    use description <- decode.field(3, decode.optional(decode.string))
    use added_at <- decode.field(4, decode.string)
    use last_checked <- decode.field(5, decode.optional(decode.string))
    use is_active <- decode.field(6, decode.bool)

    decode.success(Feed(
      id: id,
      url: url,
      title: title,
      description: description,
      added_at: added_at,
      last_checked: last_checked,
      is_active: is_active,
    ))
  }
}
