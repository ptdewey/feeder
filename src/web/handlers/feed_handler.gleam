import config
import feeds/feed.{type Feed, type NewFeed}
import feeds/repository
import feeds/service
import gleam/dynamic
import gleam/dynamic/decode
import gleam/int
import gleam/json
import gleam/list
import gleam/option.{None}
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
      case service.add_feed(db, new_feed) {
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
        Error(feed.FetchFailed(msg)) -> {
          json.object([#("error", json.string("Failed to fetch feed: " <> msg))])
          |> json.to_string
          |> wisp.json_response(400)
        }
        Error(_) -> wisp.internal_server_error()
      }
    }
    Error(msg) -> {
      echo msg
      wisp.bad_request("Invalid JSON")
    }
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
          case service.update_feed(db, feed_id, new_feed) {
            Ok(feed) -> {
              feed
              |> feed_to_json
              |> json.to_string
              |> wisp.json_response(200)
            }
            Error(feed.NotFound) -> wisp.not_found()
            Error(feed.InvalidUrl(msg)) -> {
              json.object([#("error", json.string(msg))])
              |> json.to_string
              |> wisp.json_response(400)
            }
            Error(_) -> wisp.internal_server_error()
          }
        }
        Error(_) -> wisp.bad_request("Failed to decode feed data")
      }
    }
    Error(_) -> wisp.bad_request("Invalid feed ID")
  }
}

pub fn refresh(_req: Request, db: Connection, id: String) -> Response {
  case int.parse(id) {
    Ok(feed_id) -> {
      case service.refresh_feed(db, feed_id) {
        Ok(_) -> wisp.no_content()
        Error(feed.NotFound) -> wisp.not_found()
        Error(feed.FetchFailed(msg)) -> {
          json.object([#("error", json.string("Failed to fetch feed: " <> msg))])
          |> json.to_string
          |> wisp.json_response(400)
        }
        Error(_) -> wisp.internal_server_error()
      }
    }
    Error(_) -> wisp.bad_request("Invalid feed ID")
  }
}

pub fn refresh_all(_req: Request, db: Connection) -> Response {
  let _ = config.reload_feeds_from_config(db)

  case service.refresh_all_feeds(db) {
    Ok(_) -> wisp.no_content()
    Error(_) -> wisp.internal_server_error()
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
    decode.success(feed.NewFeed(url: url, title: None, description: None))
  }

  decode.run(json_value, decoder)
}
