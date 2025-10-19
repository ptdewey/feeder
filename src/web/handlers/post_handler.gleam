import feeds/post.{type Post}
import feeds/post_repository
import gleam/int
import gleam/json
import gleam/list
import sqlight.{type Connection}
import wisp.{type Request, type Response}

pub fn list_by_feed(_req: Request, db: Connection, feed_id: String) -> Response {
  case int.parse(feed_id) {
    Ok(id) -> {
      case post_repository.get_by_feed(db, id, 50) {
        Ok(posts) -> {
          posts
          |> list.map(post_to_json)
          |> json.array(of: fn(x) { x })
          |> json.to_string
          |> wisp.json_response(200)
        }
        Error(_) -> wisp.internal_server_error()
      }
    }
    Error(_) -> wisp.bad_request("Invalid feed ID")
  }
}

pub fn list_recent(_req: Request, db: Connection) -> Response {
  case post_repository.get_recent(db, 100) {
    Ok(posts) -> {
      posts
      |> list.map(post_to_json)
      |> json.array(of: fn(x) { x })
      |> json.to_string
      |> wisp.json_response(200)
    }
    Error(_) -> wisp.internal_server_error()
  }
}

fn post_to_json(post: Post) -> json.Json {
  json.object([
    #("id", json.nullable(post.id, json.int)),
    #("feed_id", json.int(post.feed_id)),
    #("guid", json.string(post.guid)),
    #("title", json.string(post.title)),
    #("link", json.string(post.link)),
    #("description", json.nullable(post.description, json.string)),
    #("content", json.nullable(post.content, json.string)),
    #("published_at", json.nullable(post.published_at, json.string)),
    #("fetched_at", json.string(post.fetched_at)),
  ])
}
