import feeds/feed
import feeds/post_repository
import feeds/repository
import feeds/service
import gleam/http
import gleam/int
import gleam/list
import gleam/option.{None, Some}
import nakai
import nakai/attr
import nakai/html.{type Node}
import sqlight
import view/add_feeds
import view/feeds as feeds_view
import view/home as home_view
import wisp.{type Request, type Response}

pub fn home(_req: Request, db: sqlight.Connection) -> Response {
  let posts = case post_repository.get_recent(db, 50) {
    Ok(posts) -> posts
    Error(_) -> []
  }

  let html =
    html_layout("RSS Aggregator - Recent Posts", home_view.render(posts))
    |> nakai.to_string
  wisp.html_response(html, 200)
}

pub fn list_feeds(_req: Request, db: sqlight.Connection) -> Response {
  let feeds = case repository.get_all(db) {
    Ok(feeds) -> feeds
    Error(_) -> []
  }

  let html =
    html_layout("Feeds", feeds_view.render(feeds))
    |> nakai.to_string
  wisp.html_response(html, 200)
}

pub fn add_feed(req: Request, db: sqlight.Connection) -> Response {
  case req.method {
    http.Get -> {
      let html =
        html_layout("Add Feed", add_feeds.render(None))
        |> nakai.to_string
      wisp.html_response(html, 200)
    }
    http.Post -> {
      use form_data <- wisp.require_form(req)
      let url = list.key_find(form_data.values, "url") |> option.from_result

      case url {
        Some(url) -> {
          let new_feed = feed.NewFeed(url: url, title: None, description: None)
          case service.add_feed(db, new_feed) {
            Ok(_) -> wisp.redirect("/feeds")
            Error(err) -> {
              let error_msg = feed_error_to_string(err)
              let html =
                html_layout("Add Feed", add_feeds.render(Some(error_msg)))
                |> nakai.to_string
              wisp.html_response(html, 400)
            }
          }
        }
        None -> {
          let html =
            html_layout("Add Feed", add_feeds.render(Some("URL is required")))
            |> nakai.to_string
          wisp.html_response(html, 400)
        }
      }
    }
    _ -> wisp.method_not_allowed([http.Get, http.Post])
  }
}

pub fn refresh_all_feeds(req: Request, db: sqlight.Connection) -> Response {
  case req.method {
    http.Post -> {
      let _ = service.refresh_all_feeds(db)
      wisp.redirect("/feeds")
    }
    _ -> wisp.method_not_allowed([http.Post])
  }
}

pub fn refresh_feed(
  req: Request,
  db: sqlight.Connection,
  id: String,
) -> Response {
  case req.method {
    http.Post -> {
      case int.parse(id) {
        Ok(feed_id) -> {
          let _ = service.refresh_feed(db, feed_id)
          wisp.redirect("/feeds")
        }
        Error(_) -> wisp.bad_request("Invalid feed ID")
      }
    }
    _ -> wisp.method_not_allowed([http.Post])
  }
}

pub fn feed_posts(_req: Request, db: sqlight.Connection, id: String) -> Response {
  case int.parse(id) {
    Ok(feed_id) -> {
      let feed = repository.get_by_id(db, feed_id)
      let posts = case post_repository.get_by_feed(db, feed_id, 100) {
        Ok(posts) -> posts
        Error(_) -> []
      }

      case feed {
        Ok(f) -> {
          let html =
            html_layout("Posts - " <> f.title, home_view.render(posts))
            |> nakai.to_string
          wisp.html_response(html, 200)
        }
        Error(_) -> wisp.not_found()
      }
    }
    Error(_) -> wisp.bad_request("Invalid feed ID")
  }
}

fn html_layout(page_title: String, content: Node) -> Node {
  let styles =
    "
    * { margin: 0; padding: 0; box-sizing: border-box; }
    body { font-family: system-ui, -apple-system, sans-serif; line-height: 1.6; color: #333; background: #f5f5f5; }
    .container { max-width: 1200px; margin: 0 auto; padding: 20px; }
    nav { background: #2c3e50; color: white; padding: 1rem 0; margin-bottom: 2rem; }
    nav .container { display: flex; gap: 2rem; align-items: center; }
    nav a { color: white; text-decoration: none; font-weight: 500; }
    nav a:hover { text-decoration: underline; }
    h1 { margin-bottom: 1.5rem; color: #2c3e50; }
    h2 { margin-bottom: 1rem; color: #34495e; }
    .card { background: white; border-radius: 8px; padding: 1.5rem; margin-bottom: 1rem; box-shadow: 0 2px 4px rgba(0,0,0,0.1); }
    .post-item { border-bottom: 1px solid #eee; padding: 1rem 0; }
    .post-item:last-child { border-bottom: none; }
    .post-title { font-size: 1.2rem; margin-bottom: 0.5rem; }
    .post-title a { color: #3498db; text-decoration: none; }
    .post-title a:hover { text-decoration: underline; }
    .post-meta { color: #7f8c8d; font-size: 0.9rem; }
    .feed-item { padding: 1rem; border-bottom: 1px solid #eee; }
    .feed-item:last-child { border-bottom: none; }
     .feed-title { font-size: 1.1rem; font-weight: 600; margin-bottom: 0.5rem; }
     .feed-title a { color: #2c3e50; text-decoration: none; }
     .feed-title a:hover { color: #3498db; text-decoration: underline; }
     .feed-url { color: #7f8c8d; font-size: 0.9rem; }
    .btn { display: inline-block; padding: 0.75rem 1.5rem; background: #3498db; color: white; text-decoration: none; border-radius: 4px; border: none; cursor: pointer; font-size: 1rem; }
    .btn:hover { background: #2980b9; }
    .form-group { margin-bottom: 1rem; }
    .form-group label { display: block; margin-bottom: 0.5rem; font-weight: 500; }
    .form-group input { width: 100%; padding: 0.75rem; border: 1px solid #ddd; border-radius: 4px; font-size: 1rem; }
    .error { background: #e74c3c; color: white; padding: 1rem; border-radius: 4px; margin-bottom: 1rem; }
  "

  html.Html([], [
    html.Head([
      html.meta([attr.charset("UTF-8")]),
      html.meta([
        attr.name("viewport"),
        attr.content("width=device-width, initial-scale=1.0"),
      ]),
      html.title(page_title),
      html.Element("style", [], [html.Text(styles)]),
    ]),
    html.Body([], [
      html.nav([], [
        html.div([attr.class("container")], [
          html.a([attr.href("/")], [html.Text("Home")]),
          html.a([attr.href("/feeds")], [html.Text("Feeds")]),
          html.a([attr.href("/feeds/new")], [html.Text("Add Feed")]),
        ]),
      ]),
      html.div([attr.class("container")], [content]),
    ]),
  ])
}

fn feed_error_to_string(error: feed.FeedError) -> String {
  case error {
    feed.InvalidUrl(msg) -> msg
    feed.FetchFailed(msg) -> "Failed to fetch feed: " <> msg
    feed.AlreadyExists -> "This feed already exists"
    feed.NotFound -> "Feed not found"
    feed.DatabaseError(msg) -> "Database error: " <> msg
  }
}
