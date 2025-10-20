import feeds/feed.{type FeedError}
import feeds/post.{type NewPost, type Post}
import gleam/dynamic/decode
import gleam/list
import gleam/string
import sqlight.{type Connection}

pub fn insert(db: Connection, posts: NewPost) -> Result(Post, FeedError) {
  let sql =
    "
    INSERT OR IGNORE INTO POSTS (feed_id, guid, title, link, description, content, published_at, fetched_at)
    VALUES (?, ?, ?, ?, ?, ?, ?, datetime('now'))
    RETURNING id, feed_id, guid, title, link, description, content, published_at, fetched_at
    "

  let params = [
    sqlight.int(posts.feed_id),
    sqlight.text(posts.guid),
    sqlight.text(posts.title),
    sqlight.text(posts.link),
    sqlight.nullable(sqlight.text, posts.description),
    sqlight.nullable(sqlight.text, posts.content),
    sqlight.nullable(sqlight.text, posts.published_at),
  ]

  case sqlight.query(sql, db, params, post_decoder()) {
    Ok([post]) -> Ok(post)
    Ok([]) -> Error(feed.AlreadyExists)
    Ok(_) -> Error(feed.DatabaseError("Unexpected number of posts returned"))
    Error(e) ->
      Error(feed.DatabaseError("Failed to insert post: " <> string.inspect(e)))
  }
}

pub fn insert_many(
  db: Connection,
  posts: List(NewPost),
) -> Result(Int, FeedError) {
  let count =
    list.fold(posts, 0, fn(acc, post) {
      case insert(db, post) {
        Ok(_) -> acc + 1
        Error(feed.AlreadyExists) -> acc
        Error(feed.DatabaseError(msg)) -> {
          let msg = "Database error: " <> msg
          panic as msg
          // TODO: proper error handling
        }
        Error(_) -> acc
      }
    })

  Ok(count)
}

pub fn get_by_feed(
  db: Connection,
  feed_id: Int,
  limit: Int,
) -> Result(List(Post), FeedError) {
  let sql =
    "
    SELECT id, feed_id, guid, title, link, description, content, published_at, fetched_at
    FROM posts
    WHERE feed_id = ?
    ORDER BY published_at DESC, fetched_at DESC
    LIMIT ?
    "

  let params = [
    sqlight.int(feed_id),
    sqlight.int(limit),
  ]

  case sqlight.query(sql, db, params, post_decoder()) {
    Ok(posts) -> Ok(posts)
    Error(_) -> Error(feed.DatabaseError("Failed to query posts"))
  }
}

pub fn get_all(db: Connection) -> Result(List(Post), FeedError) {
  let sql =
    "
    SELECT id, feed_id, guid, title, link, description, content, published_at, fetched_at
    FROM posts
    ORDER BY published_at DESC
    "

  case sqlight.query(sql, db, [], post_decoder()) {
    Ok(posts) -> Ok(posts)
    Error(_) -> Error(feed.DatabaseError("Failed to query posts"))
  }
}

pub fn get_recent(db: Connection, limit: Int) -> Result(List(Post), FeedError) {
  let sql =
    "
    SELECT id, feed_id, guid, title, link, description, content, published_at, fetched_at
    FROM posts
    ORDER BY 
      COALESCE(published_at, fetched_at) DESC,
      fetched_at DESC
    LIMIT ?
    "

  case sqlight.query(sql, db, [sqlight.int(limit)], post_decoder()) {
    Ok(feeds) -> Ok(feeds)
    Error(_) -> Error(feed.DatabaseError("Failed to query feeds"))
  }
}

fn post_decoder() -> decode.Decoder(Post) {
  {
    use id <- decode.field(0, decode.optional(decode.int))
    use feed_id <- decode.field(1, decode.int)
    use guid <- decode.field(2, decode.string)
    use title <- decode.field(3, decode.string)
    use link <- decode.field(4, decode.string)
    use description <- decode.field(5, decode.optional(decode.string))
    use content <- decode.field(6, decode.optional(decode.string))
    use published_at <- decode.field(7, decode.optional(decode.string))
    use fetched_at <- decode.field(8, decode.string)

    decode.success(post.Post(
      id: id,
      feed_id: feed_id,
      guid: guid,
      title: title,
      link: link,
      description: description,
      content: content,
      published_at: published_at,
      fetched_at: fetched_at,
    ))
  }
}
