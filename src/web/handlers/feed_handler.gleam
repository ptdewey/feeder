import feeds/feed.{type Feed, type NewFeed}
import feeds/repository
import gleam/json
import gleam/list
import sqlight.{type Connection}
import wisp.{type Request, type Response}

pub fn list(_req: Request, db: Connection) -> Response {
  case repository.get_all(db) {
    Ok(feeds) -> {
      feeds
      |> list.map(feed_to_json)
      |> json.array(of: fn(x) { x })
      |> json.to_string
      |> wisp.json_response(200)
    }
    Error(_) -> {
      json.object([#("error", json.string("Failed to fetch feeds"))])
      |> json.to_string
      |> wisp.json_response(500)
    }
  }
}

pub fn create(req: Request, db: Connection) {
  todo
}

pub fn get(req: Request, db: Connection, id: int) {
  todo
}

pub fn delete(req: Request, db: Connection, id: int) {
  todo
}

pub fn update(req: Request, db: Connection, id: int) {
  todo
}

fn feed_to_json(feed: Feed) -> json.Json {
  todo
}
