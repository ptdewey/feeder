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
import reading_list/service as reading_list_service
import sqlight
import view/add_feeds
import view/archive as archive_view
import view/feeds as feeds_view
import view/home as home_view
import view/login as login_view
import view/reading_list as reading_list_view
import wisp.{type Request, type Response}

pub fn login_page(req: Request) -> Response {
  let error_msg = case wisp.get_query(req) {
    [#("error", "invalid")] -> option.Some("Invalid username or password")
    [#("error", "locked"), #("minutes", minutes)] -> 
      option.Some("Too many failed attempts. Please try again in " <> minutes <> " minute(s).")
    _ -> option.None
  }

  let html = login_view.render(error_msg) |> nakai.to_string
  wisp.html_response(html, 200)
}

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

pub fn reading_list(_req: Request, db: sqlight.Connection) -> Response {
  let items = case reading_list_service.get_all_items(db) {
    Ok(items) -> items
    Error(_) -> []
  }

  let html =
    html_layout("Reading List", reading_list_view.render(items))
    |> nakai.to_string
  wisp.html_response(html, 200)
}

pub fn archive_page(_req: Request, db: sqlight.Connection) -> Response {
  let items = case reading_list_service.get_archived_items(db) {
    Ok(items) -> items
    Error(_) -> []
  }

  let html =
    html_layout("Archive", archive_view.render(items))
    |> nakai.to_string
  wisp.html_response(html, 200)
}

fn html_layout(page_title: String, content: Node) -> Node {
  let styles =
    "
    * { margin: 0; padding: 0; box-sizing: border-box; }
    body { font-family: Georgia, 'Times New Roman', serif; line-height: 1.7; color: #3d3428; background: #e8dfc5; font-size: 1.1rem; }
    .container { max-width: 1200px; margin: 0 auto; padding: 20px; }
    nav { background: #8b7355; color: #f4ecd8; padding: 1rem 0; margin-bottom: 2rem; }
    nav .container { display: flex; gap: 2rem; align-items: center; flex-wrap: wrap; }
    nav a { color: #f4ecd8; text-decoration: none; font-weight: 500; font-size: 1.1rem; }
    nav a:hover { text-decoration: underline; }
    nav .nav-logout { margin-left: auto; }
    h1 { margin-bottom: 1.5rem; color: #5d4e37; font-size: 2rem; }
    h2 { margin-bottom: 1rem; color: #6b5d4f; font-size: 1.5rem; }
    .card { background: #f4ecd8; border-radius: 8px; padding: 1.5rem; margin-bottom: 1rem; box-shadow: 0 2px 4px rgba(61, 52, 40, 0.1); border: 1px solid #d4cdc0; }
    .post-item { border-bottom: 1px solid #d4cdc0; padding: 0.5rem 0; }
    .post-item:last-child { border-bottom: none; }
    .post-title { font-size: 1.3rem; margin-bottom: 0.5rem; }
    .post-title a { color: #6b5d4f; text-decoration: none; }
    .post-title a:hover { text-decoration: underline; color: #8b7355; }
    .post-meta { color: #9b8b7e; font-size: 1rem; }
    .feed-item { padding: 0.5rem; border-bottom: 1px solid #d4cdc0; }
    .feed-item:last-child { border-bottom: none; }
    .feed-title { font-size: 1.2rem; font-weight: 600; margin-bottom: 0.5rem; }
    .feed-title a { color: #5d4e37; text-decoration: none; }
    .feed-title a:hover { color: #8b7355; text-decoration: underline; }
    .feed-url { color: #9b8b7e; font-size: 1rem; }
    .btn { display: inline-block; padding: 0.75rem 1.5rem; background: #a89074; color: #f4ecd8; text-decoration: none; border-radius: 4px; border: none; cursor: pointer; font-size: 1.1rem; font-family: Georgia, 'Times New Roman', serif; }
    .btn:hover { background: #8b7355; }
    .form-group { margin-bottom: 1rem; }
    .form-group label { display: block; margin-bottom: 0.5rem; font-weight: 500; font-size: 1.1rem; }
    .form-group input { width: 100%; padding: 0.75rem; border: 1px solid #d4cdc0; border-radius: 4px; font-size: 1.1rem; background: #f4ecd8; color: #3d3428; font-family: Georgia, 'Times New Roman', serif; }
    .error { background: #b5745a; color: #f4ecd8; padding: 1rem; border-radius: 4px; margin-bottom: 1rem; font-size: 1.1rem; }
    .item-with-action { display: flex; justify-content: space-between; align-items: flex-start; flex-wrap: wrap; gap: 1rem; }
    .item-content { flex: 1; min-width: 250px; }
    .item-action { flex-shrink: 0; }
    @media (max-width: 768px) {
      nav .container { gap: 1rem; }
      nav a { font-size: 1rem; }
      nav .nav-logout { width: 100%; margin-left: 0; margin-top: 0.5rem; }
      .item-with-action { flex-direction: column; align-items: stretch; }
      .item-action { width: 100%; }
      .item-action form { width: 100%; }
      .item-action button { width: 100%; }
    }
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
          html.a([attr.href("/reading-list")], [html.Text("Reading List")]),
          html.a([attr.href("/archive")], [html.Text("Archive")]),
          html.div([attr.class("nav-logout")], [
            html.form(
              [
                attr.method("POST"),
                attr.action("/auth/logout"),
                attr.style("display: inline;"),
              ],
              [
                html.button(
                  [
                    attr.type_("submit"),
                    attr.style(
                      "background: none; border: none; color: #f4ecd8; cursor: pointer; font-size: 1.1rem; font-family: Georgia, 'Times New Roman', serif; font-weight: 500;",
                    ),
                  ],
                  [html.Text("Logout")],
                ),
              ],
            ),
          ]),
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
