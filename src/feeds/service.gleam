import feeds/feed.{type Feed, type FeedError, type FeedMetadata, type NewFeed}
import feeds/post
import feeds/post_repository
import feeds/repository
import feeds/validator
import gleam/list
import gleam/option.{None, Some}
import gleam/result
import gleam/string
import http/client
import simplifile
import sqlight.{type Connection}
import xml/parser

pub fn fetch_posts(db: Connection, feed: Feed) -> Result(Int, FeedError) {
  case feed.id {
    Some(feed_id) -> {
      use xml_content <- result.try(
        client.fetch_feed(feed.url)
        |> result.map_error(fn(msg) { feed.FetchFailed(msg) }),
      )

      use parsed_feed <- result.try(
        parser.parse_feed(xml_content)
        |> result.map_error(fn(msg) { feed.FetchFailed(msg) }),
      )

      // Store posts
      let posts =
        list.map(parsed_feed.posts, fn(parsed_post) {
          post.NewPost(
            feed_id: feed_id,
            guid: parsed_post.guid,
            title: parsed_post.title,
            link: parsed_post.link,
            description: parsed_post.description,
            content: parsed_post.content,
            published_at: parsed_post.published_at,
          )
        })

      use count <- result.try(
        post_repository.insert_many(db, posts)
        |> result.map_error(fn(_) {
          feed.DatabaseError("Failed to insert posts")
        }),
      )

      use _ <- result.try(repository.update_last_checked(db, feed_id))

      Ok(count)
    }
    None -> Error(feed.DatabaseError("Feed has no ID"))
  }
}

pub fn refresh_feed(db: Connection, id: Int) -> Result(Int, FeedError) {
  use feed <- result.try(repository.get_by_id(db, id))
  fetch_posts(db, feed)
}

pub fn refresh_all_feeds(db: Connection) -> Result(Int, FeedError) {
  use feeds <- result.try(repository.get_all(db))

  let total =
    list.fold(feeds, 0, fn(acc, feed) {
      case fetch_posts(db, feed) {
        Ok(count) -> acc + count
        Error(_) -> acc
      }
    })

  Ok(total)
}

pub fn add_feed(db: Connection, new_feed: NewFeed) -> Result(Feed, FeedError) {
  use _ <- result.try(validator.validate_url(new_feed.url))

  case repository.get_by_url(db, new_feed.url) {
    Ok(_) -> Error(feed.AlreadyExists)
    Error(feed.NotFound) -> {
      use metadata <- result.try(fetch_feed_metadata(new_feed.url))

      let final_feed =
        feed.NewFeed(
          url: new_feed.url,
          title: Some(metadata.title),
          description: metadata.description,
        )

      use inserted_feed <- result.try(repository.insert(db, final_feed))

      let _ = save_feed_url_to_config(new_feed.url)

      Ok(inserted_feed)
    }
    Error(e) -> Error(e)
  }
}

pub fn update_feed(
  db: Connection,
  id: Int,
  new_feed: NewFeed,
) -> Result(Feed, FeedError) {
  use _ <- result.try(validator.validate_url(new_feed.url))
  repository.update(db, id, new_feed)
}

pub fn validate_all_feeds(db: Connection) -> Result(Nil, FeedError) {
  use feeds <- result.try(repository.get_all(db))

  feeds
  |> list.each(fn(feed) {
    case client.check_feed(feed.url) {
      Ok(_) ->
        repository.update_last_checked(db, case feed.id {
          option.Some(id) -> id
          option.None -> panic as "Missing feed ID"
        })
      Error(_) -> Ok(Nil)
    }
  })

  Ok(Nil)
}

fn fetch_feed_metadata(url: String) -> Result(FeedMetadata, FeedError) {
  use xml_content <- result.try(
    client.fetch_feed(url)
    |> result.map_error(fn(msg) { feed.FetchFailed(msg) }),
  )

  use parsed_xml <- result.try(
    parser.parse_feed(xml_content)
    |> result.map_error(fn(msg) { feed.FetchFailed(msg) }),
  )

  Ok(feed.FeedMetadata(
    title: parsed_xml.title,
    description: parsed_xml.description,
  ))
}

fn save_feed_url_to_config(url: String) -> Result(Nil, String) {
  case simplifile.read("feeds.txt") {
    Ok(content) -> {
      let urls = parse_feed_urls(content)
      case list.contains(urls, url) {
        True -> Ok(Nil)
        False -> {
          let new_content = content <> "\n" <> url
          case simplifile.write("feeds.txt", new_content) {
            Ok(_) -> Ok(Nil)
            Error(_) -> Error("Failed to write to feeds.txt")
          }
        }
      }
    }
    Error(_) -> {
      case simplifile.write("feeds.txt", url) {
        Ok(_) -> Ok(Nil)
        Error(_) -> Error("Failed to create feeds.txt")
      }
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
