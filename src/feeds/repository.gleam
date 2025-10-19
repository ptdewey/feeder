import feeds/feed.{type Feed, type FeedError, type NewFeed}
import gleam/dynamic/decode
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

pub fn get_by_id(db: Connection, id: Int) -> Result(Feed, FeedError) {
  let sql =
    "
    SELECT id, url, title, description, added_at, last_checked, is_active
    FROM feeds 
    WHERE id = ?
    "

  case sqlight.query(sql, db, [sqlight.int(id)], feed_decoder()) {
    Ok([feed]) -> Ok(feed)
    Ok([]) -> Error(feed.NotFound)
    Ok(_) -> Error(feed.DatabaseError("Multiple feeds found"))
    Error(_) -> Error(feed.DatabaseError("Query failed"))
  }
}

pub fn get_by_url(db: Connection, url: String) -> Result(Feed, FeedError) {
  let sql =
    "
    SELECT id, url, title, description, added_at, last_checked, is_active
    FROM feeds 
    WHERE url = ?
    "

  case sqlight.query(sql, db, [sqlight.text(url)], feed_decoder()) {
    Ok([feed]) -> Ok(feed)
    Ok([]) -> Error(feed.NotFound)
    Ok(_) -> Error(feed.DatabaseError("Multiple feeds found"))
    Error(_) -> Error(feed.DatabaseError("Query failed"))
  }
}

pub fn insert(db: Connection, new_feed: NewFeed) -> Result(Feed, FeedError) {
  let sql =
    "
    INSERT INTO feeds (url, title, description, added_at, is_active)
    VALUES (?, ?, ?, datetime('now'), 1)
    RETURNING id, url, title, description, added_at, last_checked, is_active
    "

  let params = [
    sqlight.text(new_feed.url),
    sqlight.nullable(sqlight.text, new_feed.title),
    sqlight.nullable(sqlight.text, new_feed.description),
  ]

  case sqlight.query(sql, db, params, feed_decoder()) {
    Ok([feed]) -> Ok(feed)
    Ok(_) -> Error(feed.DatabaseError("Insert failed"))
    Error(_) -> Error(feed.DatabaseError("Insert failed"))
  }
}

pub fn update(
  db: Connection,
  id: Int,
  new_feed: NewFeed,
) -> Result(Feed, FeedError) {
  let sql =
    "
    UPDATE feeds
    SET url = ?, title = ?, description = ?
    WHERE id = ?
    RETURNING id, url, title, description, added_at, last_checked, is_active
    "

  let params = [
    sqlight.text(new_feed.url),
    sqlight.nullable(sqlight.text, new_feed.title),
    sqlight.nullable(sqlight.text, new_feed.description),
    sqlight.int(id),
  ]

  case sqlight.query(sql, db, params, feed_decoder()) {
    Ok([feed]) -> Ok(feed)
    Ok([]) -> Error(feed.NotFound)
    Ok(_) -> Error(feed.DatabaseError("Update failed"))
    Error(_) -> Error(feed.DatabaseError("Update failed"))
  }
}

pub fn delete(db: Connection, id: Int) -> Result(Nil, FeedError) {
  let sql = "DELETE FROM feeds WHERE id = ?"

  case sqlight.query(sql, db, [sqlight.int(id)], { decode.success(Nil) }) {
    Ok(_) -> Ok(Nil)
    Error(_) -> Error(feed.DatabaseError("Delete failed"))
  }
}

pub fn update_last_checked(db: Connection, id: Int) -> Result(Nil, FeedError) {
  let sql =
    "
    UPDATE feeds
    SET last_checked = datetime('now')
    WHERE id = ?
    "

  case sqlight.query(sql, db, [sqlight.int(id)], { decode.success(Nil) }) {
    Ok([feed]) -> Ok(feed)
    Ok([]) -> Error(feed.NotFound)
    Ok(_) -> Error(feed.DatabaseError("Update failed"))
    Error(_) -> Error(feed.DatabaseError("Update failed"))
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
    use is_active <- decode.field(6, {
      use value <- decode.then(decode.int)
      case value {
        0 -> decode.success(False)
        1 -> decode.success(True)
        _ -> decode.failure(False, "Expected 0 or 1 for boolean field")
      }
    })

    decode.success(feed.Feed(
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
