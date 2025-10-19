import feeds/feed
import feeds/post
import feeds/post_repository
import feeds/repository
import feeds/service
import gleam/http
import gleam/int
import gleam/list
import gleam/option.{None, Some}
import gleam/string
import sqlight
import wisp.{type Request, type Response}

pub fn home(_req: Request, db: sqlight.Connection) -> Response {
  let posts = case post_repository.get_recent(db, 50) {
    Ok(posts) -> posts
    Error(_) -> []
  }

  let html = html_layout("RSS Aggregator - Recent Posts", render_home(posts))
  wisp.html_response(html, 200)
}

pub fn list_feeds(_req: Request, db: sqlight.Connection) -> Response {
  let feeds = case repository.get_all(db) {
    Ok(feeds) -> feeds
    Error(_) -> []
  }

  let html = html_layout("Feeds", render_feeds(feeds))
  wisp.html_response(html, 200)
}

pub fn add_feed(req: Request, db: sqlight.Connection) -> Response {
  case req.method {
    http.Get -> {
      let html = html_layout("Add Feed", render_add_feed_form(None))
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
                html_layout("Add Feed", render_add_feed_form(Some(error_msg)))
              wisp.html_response(html, 400)
            }
          }
        }
        None -> {
          let html =
            html_layout("Add Feed", render_add_feed_form(Some("URL is required")))
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

pub fn refresh_feed(req: Request, db: sqlight.Connection, id: String) -> Response {
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

fn html_layout(title: String, content: String) -> String {
  "<!DOCTYPE html>
<html lang=\"en\">
<head>
  <meta charset=\"UTF-8\">
  <meta name=\"viewport\" content=\"width=device-width, initial-scale=1.0\">
  <title>" <> title <> "</title>
  <style>
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
    .feed-url { color: #7f8c8d; font-size: 0.9rem; }
    .btn { display: inline-block; padding: 0.75rem 1.5rem; background: #3498db; color: white; text-decoration: none; border-radius: 4px; border: none; cursor: pointer; font-size: 1rem; }
    .btn:hover { background: #2980b9; }
    .form-group { margin-bottom: 1rem; }
    .form-group label { display: block; margin-bottom: 0.5rem; font-weight: 500; }
    .form-group input { width: 100%; padding: 0.75rem; border: 1px solid #ddd; border-radius: 4px; font-size: 1rem; }
    .error { background: #e74c3c; color: white; padding: 1rem; border-radius: 4px; margin-bottom: 1rem; }
  </style>
</head>
<body>
  <nav>
    <div class=\"container\">
      <a href=\"/\">Home</a>
      <a href=\"/feeds\">Feeds</a>
      <a href=\"/feeds/new\">Add Feed</a>
    </div>
  </nav>
  <div class=\"container\">
    " <> content <> "
  </div>
</body>
</html>"
}

fn render_home(posts: List(post.Post)) -> String {
  "<h1>Recent Posts</h1>
  <form method=\"POST\" action=\"/feeds/refresh\" style=\"margin-bottom: 1rem;\">
    <button type=\"submit\" class=\"btn\" style=\"background: #27ae60;\">Refresh All Feeds</button>
  </form>
  <div class=\"card\">"
  <> case posts {
    [] -> "<p>No posts yet. Add some feeds to get started!</p>"
    _ ->
      posts
      |> list.map(fn(post) {
        let description = case post.description {
          Some(desc) -> "<p class=\"post-meta\">" <> desc <> "</p>"
          None -> ""
        }
        let date = case post.published_at {
          Some(published) -> published
          None -> post.fetched_at
        }
        "<div class=\"post-item\">
          <div class=\"post-title\"><a href=\""
        <> post.link
        <> "\" target=\"_blank\">"
        <> post.title
        <> "</a></div>"
        <> description
        <> "<div class=\"post-meta\">Published: "
        <> date
        <> "</div>
        </div>"
      })
      |> string.join("")
  }
  <> "</div>"
}

fn render_feeds(feeds: List(feed.Feed)) -> String {
  "<h1>Your Feeds</h1>
  <div style=\"margin-bottom: 1rem;\">
    <a href=\"/feeds/new\" class=\"btn\">Add New Feed</a>
    <form method=\"POST\" action=\"/feeds/refresh\" style=\"display: inline; margin-left: 0.5rem;\">
      <button type=\"submit\" class=\"btn\" style=\"background: #27ae60;\">Refresh All Feeds</button>
    </form>
  </div>
  <div class=\"card\">"
  <> case feeds {
    [] -> "<p>No feeds yet. Add one to get started!</p>"
    _ ->
      feeds
      |> list.map(fn(feed) {
        let description = case feed.description {
          Some(desc) -> "<p class=\"feed-url\">" <> desc <> "</p>"
          None -> ""
        }
        let last_checked = case feed.last_checked {
          Some(checked) -> "Last checked: " <> checked
          None -> "Never checked"
        }
        let id_str = case feed.id {
          Some(id) -> int.to_string(id)
          None -> "0"
        }
        "<div class=\"feed-item\">
          <div class=\"feed-title\">"
        <> feed.title
        <> "</div>
          <p class=\"feed-url\">"
        <> feed.url
        <> "</p>"
        <> description
        <> "<p class=\"post-meta\">"
        <> last_checked
        <> "</p>
          <form method=\"POST\" action=\"/feeds/"
        <> id_str
        <> "/refresh\" style=\"display: inline;\">
            <button type=\"submit\" class=\"btn\" style=\"font-size: 0.9rem; padding: 0.5rem 1rem;\">Refresh</button>
          </form>
        </div>"
      })
      |> string.join("")
  }
  <> "</div>"
}

fn render_add_feed_form(error: option.Option(String)) -> String {
  let error_html = case error {
    Some(msg) -> "<div class=\"error\">" <> msg <> "</div>"
    None -> ""
  }

  "<h1>Add New Feed</h1>"
  <> error_html
  <> "<div class=\"card\">
    <form method=\"POST\" action=\"/feeds/new\">
      <div class=\"form-group\">
        <label for=\"url\">Feed URL</label>
        <input type=\"url\" id=\"url\" name=\"url\" placeholder=\"https://example.com/feed.xml\" required>
      </div>
      <button type=\"submit\" class=\"btn\">Add Feed</button>
      <a href=\"/feeds\" style=\"margin-left: 1rem;\">Cancel</a>
    </form>
  </div>"
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
