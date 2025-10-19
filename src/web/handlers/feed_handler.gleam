import feeds/feed.{type Feed, type NewFeed}
import feeds/repository
import gleam/dynamic
import gleam/dynamic/decode
import gleam/int
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
  use json <- wisp.require_json(req)

  case decode_new_feed(json) {
    Ok(new_feed) -> {
      case repository.insert(db, new_feed) {
        Ok(feed) -> {
          feed
          |> feed_to_json
          |> json.to_string
          |> wisp.json_response(201)
        }
        Error(feed.InvalidUrl(msg)) -> {
          json.object([#("error", json.string(msg))])
          |> json.to_string
          |> wisp.json_response(400)
        }
        Error(feed.AlreadyExists) -> {
          json.object([#("error", json.string("Feed already exists"))])
          |> json.to_string
          |> wisp.json_response(409)
        }
        Error(_) -> wisp.internal_server_error()
      }
    }
    Error(_) -> wisp.internal_server_error()
  }
}

pub fn get(_req: Request, db: Connection, id: String) -> Response {
  case int.parse(id) {
    Ok(feed_id) -> {
      case repository.get_by_id(db, feed_id) {
        Ok(feed) -> {
          feed
          |> feed_to_json
          |> json.to_string
          |> wisp.json_response(200)
        }
        Error(feed.NotFound) -> wisp.not_found()
        Error(_) -> wisp.internal_server_error()
      }
    }
    Error(_) -> wisp.bad_request("Invalid feed ID")
  }
}

pub fn delete(_req: Request, db: Connection, id: String) {
  case int.parse(id) {
    Ok(feed_id) -> {
      case repository.delete(db, feed_id) {
        Ok(_) -> wisp.no_content()
        Error(feed.NotFound) -> wisp.not_found()
        Error(_) -> wisp.internal_server_error()
      }
    }
    Error(_) -> wisp.bad_request("Invalid feed ID")
  }
}

pub fn update(req: Request, db: Connection, id: String) {
  case int.parse(id) {
    Ok(feed_id) -> {
      use json <- wisp.require_json(req)

      case decode_new_feed(json) {
        Ok(new_feed) -> {
          case repository.update(db, feed_id, new_feed) {
            Ok(feed) -> {
              feed
              |> feed_to_json
              |> json.to_string
              |> wisp.json_response(200)
            }
            Error(feed.NotFound) -> wisp.not_found()
            Error(_) -> wisp.internal_server_error()
          }
        }
        Error(_) -> wisp.bad_request("Failed to decode feed data")
      }
    }
    Error(_) -> wisp.bad_request("Invalid feed ID")
  }
}

fn feed_to_json(feed: Feed) -> json.Json {
  json.object([
    #("id", json.nullable(feed.id, json.int)),
    #("url", json.string(feed.url)),
    #("title", json.string(feed.title)),
    #("description", json.nullable(feed.description, json.string)),
    #("added_at", json.string(feed.added_at)),
    #("last_checked", json.nullable(feed.last_checked, json.string)),
    #("is_active", json.bool(feed.is_active)),
  ])
}

fn decode_new_feed(
  json_value: dynamic.Dynamic,
) -> Result(NewFeed, List(decode.DecodeError)) {
  let decoder = {
    use url <- decode.field("url", decode.string)
    use title <- decode.field("title", decode.string)
    use description <- decode.field(
      "description",
      decode.optional(decode.string),
    )

    decode.success(feed.NewFeed(
      url: url,
      title: title,
      description: description,
    ))
  }

  decode.run(json_value, decoder)
}
