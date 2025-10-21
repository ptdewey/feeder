import feeds/feed.{type Feed, type FeedError}
import feeds/repository
import feeds/service
import gleam/erlang/process
import gleam/list
import gleam/option.{None}
import gleam/string
import simplifile
import sqlight.{type Connection}
import wisp

pub fn load_initial_feeds(db: Connection) -> Result(Nil, String) {
  case repository.get_all(db) {
    Ok([]) -> {
      wisp.log_info(
        "No feeds found in database. Loading initial feeds from config...",
      )
      load_feeds_from_file(db, "feeds.txt")
    }
    Ok(_feeds) -> {
      wisp.log_info("Database already contains feeds. Skipping initial load.")
      Ok(Nil)
    }
    Error(_) -> {
      wisp.log_warning("Error checking database. Skipping initial load.")
      Ok(Nil)
    }
  }
}

type AddFeedResult {
  AddFeedResult(url: String, result: Result(Feed, FeedError))
}

fn load_feeds_from_file(db: Connection, path: String) -> Result(Nil, String) {
  case simplifile.read(path) {
    Ok(content) -> {
      let urls = parse_feed_urls(content)
      wisp.log_info(
        "Found "
        <> string.inspect(list.length(urls))
        <> " feed URLs in config file",
      )

      let result_subject = process.new_subject()

      list.each(urls, fn(url) {
        process.spawn(fn() {
          wisp.log_info("Adding feed: " <> url)
          let new_feed = feed.NewFeed(url: url, title: None, description: None)
          let result = service.add_feed(db, new_feed)
          process.send(result_subject, AddFeedResult(url, result))
        })
      })

      list.range(1, list.length(urls))
      |> list.each(fn(_) {
        case process.receive(result_subject, 30_000) {
          Ok(AddFeedResult(url, Ok(_))) ->
            wisp.log_info("Successfully added: " <> url)
          Ok(AddFeedResult(url, Error(e))) ->
            wisp.log_error(
              "Failed to add: " <> url <> " - " <> feed_error_to_string(e),
            )
          Error(Nil) -> wisp.log_error("Timeout waiting for feed result")
        }
      })

      Ok(Nil)
    }
    Error(_) -> {
      wisp.log_warning(
        "Config file '" <> path <> "' not found. Skipping initial load.",
      )
      Ok(Nil)
    }
  }
}

fn parse_feed_urls(content: String) -> List(String) {
  content
  |> string.split("\n")
  |> list.map(string.trim)
  |> list.filter(fn(line) {
    !string.is_empty(line) && !string.starts_with(line, "#")
  })
}

pub fn save_feed_url(url: String) -> Result(Nil, String) {
  case simplifile.read("feeds.txt") {
    Ok(content) -> {
      let urls = parse_feed_urls(content)
      case list.contains(urls, url) {
        True -> Ok(Nil)
        False -> {
          let new_content = content <> url
          case simplifile.write("feeds.txt", new_content) {
            Ok(_) -> Ok(Nil)
            Error(_) -> Error("Failed to write to feeds.txt")
          }
        }
      }
    }
    Error(_) -> {
      case simplifile.write("feeds.txt", url <> "\n") {
        Ok(_) -> Ok(Nil)
        Error(_) -> Error("Failed to create feeds.txt")
      }
    }
  }
}

pub fn reload_feeds_from_config(db: Connection) -> Result(Nil, String) {
  load_feeds_from_file(db, "feeds.txt")
}

fn feed_error_to_string(error: FeedError) -> String {
  case error {
    feed.InvalidUrl(msg) -> msg
    feed.FetchFailed(msg) -> "Failed to fetch feed: " <> msg
    feed.AlreadyExists -> "This feed already exists"
    feed.NotFound -> "Feed not found"
    feed.DatabaseError(msg) -> "Database error: " <> msg
  }
}
