import auth/middleware
import auth/session_store
import gleam/http
import gleam/string
import simplifile
import sqlight
import web/handlers/auth_handler
import web/handlers/feed_handler
import web/handlers/page_handler
import web/handlers/post_handler
import web/handlers/reading_list_handler
import wisp.{type Request, type Response}

pub fn handle_request(
  req: Request,
  db: sqlight.Connection,
  session_store: session_store.SessionStore,
) -> Response {
  use _req <- base_middleware(req)

  case wisp.path_segments(req) {
    ["login"] -> page_handler.login_page(req)
    ["auth", "login"] -> auth_handler.login(req, db, session_store)
    ["auth", "logout"] -> auth_handler.logout(req, session_store)
    ["manifest.json"] -> serve_manifest(req)
    ["service-worker.js"] -> serve_service_worker(req)
    ["static", ..rest] -> serve_static(req, rest)

    _ -> {
      use _req, _username <- middleware.require_auth(req, session_store)

      case wisp.path_segments(req) {
        [] -> page_handler.home(req, db)
        ["feeds"] -> page_handler.list_feeds(req, db)
        ["feeds", "new"] -> page_handler.add_feed(req, db)
        ["feeds", "refresh"] -> page_handler.refresh_all_feeds(req, db)
        ["feeds", id, "posts"] -> page_handler.feed_posts(req, db, id)
        ["feeds", id, "refresh"] -> page_handler.refresh_feed(req, db, id)
        ["reading-list"] -> page_handler.reading_list(req, db)
        ["archive"] -> page_handler.archive_page(req, db)

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

        ["api", "reading-list"] -> {
          case req.method {
            http.Get -> reading_list_handler.list(req, db)
            http.Post -> reading_list_handler.create(req, db)
            _ -> wisp.method_not_allowed([http.Get, http.Post])
          }
        }
        ["api", "reading-list", id, "archive"] -> {
          case req.method {
            http.Post -> reading_list_handler.archive(req, db, id)
            _ -> wisp.method_not_allowed([http.Post])
          }
        }

        _ -> wisp.not_found()
      }
    }
  }
}

fn base_middleware(
  req: Request,
  handle_request: fn(Request) -> Response,
) -> Response {
  let req = wisp.method_override(req)
  use <- wisp.log_request(req)
  use <- wisp.rescue_crashes
  use req <- wisp.handle_head(req)

  handle_request(req)
}

fn serve_manifest(_req: Request) -> Response {
  let manifest = "{
  \"name\": \"RSS Feed Aggregator\",
  \"short_name\": \"RSS Feeder\",
  \"description\": \"A simple RSS feed aggregator for reading your favorite feeds\",
  \"start_url\": \"/\",
  \"display\": \"standalone\",
  \"background_color\": \"#e8dfc5\",
  \"theme_color\": \"#8b7355\",
  \"orientation\": \"portrait-primary\",
  \"icons\": [
    {
      \"src\": \"/static/icon-192.svg\",
      \"sizes\": \"192x192\",
      \"type\": \"image/svg+xml\",
      \"purpose\": \"any maskable\"
    },
    {
      \"src\": \"/static/icon-512.svg\",
      \"sizes\": \"512x512\",
      \"type\": \"image/svg+xml\",
      \"purpose\": \"any maskable\"
    }
  ]
}"
  wisp.response(200)
  |> wisp.set_header("content-type", "application/manifest+json")
  |> wisp.set_body(wisp.Text(manifest))
}

fn serve_service_worker(_req: Request) -> Response {
  case simplifile.read("priv/static/service-worker.js") {
    Ok(content) -> 
      wisp.response(200)
      |> wisp.set_header("content-type", "application/javascript")
      |> wisp.set_body(wisp.Text(content))
    Error(_) -> wisp.not_found()
  }
}

fn serve_static(_req: Request, path: List(String)) -> Response {
  case path {
    [] -> wisp.not_found()
    _ -> {
      let file_path = "priv/static/" <> string.join(path, "/")
      case simplifile.read(file_path) {
        Ok(content) -> {
          let path_str = string.join(path, "/")
          let content_type = case string.ends_with(path_str, ".png") {
            True -> "image/png"
            False -> case string.ends_with(path_str, ".jpg") || string.ends_with(path_str, ".jpeg") {
              True -> "image/jpeg"
              False -> case string.ends_with(path_str, ".svg") {
                True -> "image/svg+xml"
                False -> case string.ends_with(path_str, ".ico") {
                  True -> "image/x-icon"
                  False -> "application/octet-stream"
                }
              }
            }
          }
          wisp.response(200)
          |> wisp.set_header("content-type", content_type)
          |> wisp.set_body(wisp.Text(content))
        }
        Error(_) -> wisp.not_found()
      }
    }
  }
}
