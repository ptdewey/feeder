import gleam/http
import sqlight
import web/handlers/feed_handler
import web/handlers/page_handler
import web/handlers/post_handler
import wisp.{type Request, type Response}

pub fn handle_request(req: Request, db: sqlight.Connection) -> Response {
  use _req <- middleware(req)

  case wisp.path_segments(req) {
    // HTML pages
    [] -> page_handler.home(req, db)
    ["feeds"] -> page_handler.list_feeds(req, db)
    ["feeds", "new"] -> page_handler.add_feed(req, db)
    ["feeds", "refresh"] -> page_handler.refresh_all_feeds(req, db)
    ["feeds", id, "refresh"] -> page_handler.refresh_feed(req, db, id)

    // API endpoints
    ["api", "feeds"] -> {
      case req.method {
        http.Get -> feed_handler.list(req, db)
        http.Put -> feed_handler.create(req, db)
        _ -> wisp.method_not_allowed([http.Get, http.Put])
      }
    }
    ["api", "feeds", "refresh"] -> {
      case req.method {
        http.Post -> feed_handler.refresh_all(req, db)
        _ -> wisp.method_not_allowed([http.Post])
      }
    }
    ["api", "feeds", id] -> {
      case req.method {
        http.Get -> feed_handler.get(req, db, id)
        http.Delete -> feed_handler.delete(req, db, id)
        http.Put -> feed_handler.update(req, db, id)
        _ -> wisp.method_not_allowed([http.Get, http.Delete, http.Put])
      }
    }
    ["api", "feeds", id, "posts"] -> {
      case req.method {
        http.Get -> post_handler.list_by_feed(req, db, id)
        _ -> wisp.method_not_allowed([http.Get])
      }
    }
    ["api", "feeds", id, "refresh"] -> {
      case req.method {
        http.Post -> feed_handler.refresh(req, db, id)
        _ -> wisp.method_not_allowed([http.Post])
      }
    }
    ["api", "posts"] -> {
      case req.method {
        http.Get -> post_handler.list_recent(req, db)
        _ -> wisp.method_not_allowed([http.Get])
      }
    }

    // Static files
    // ["static", ..rest] -> {
    //   let path = string.join(rest, "/")
    //   wisp.serve_static(req, under: "/static", from: "/priv/static")
    // }
    _ -> wisp.not_found()
  }
}

fn middleware(req: Request, handle_request: fn(Request) -> Response) -> Response {
  let req = wisp.method_override(req)
  use <- wisp.log_request(req)
  use <- wisp.rescue_crashes
  use req <- wisp.handle_head(req)

  handle_request(req)
}
