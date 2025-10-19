import feeds/feed
import gleam/option.{None, Some}
import gleeunit/should

pub fn new_feed_creation_test() {
  let new_feed = feed.NewFeed(
    url: "https://example.com/feed.xml",
    title: Some("Test Feed"),
    description: Some("A test description"),
  )

  new_feed.url
  |> should.equal("https://example.com/feed.xml")
  
  new_feed.title
  |> should.equal(Some("Test Feed"))
  
  new_feed.description
  |> should.equal(Some("A test description"))
}

pub fn new_feed_with_optional_none_test() {
  let new_feed = feed.NewFeed(
    url: "https://example.com/feed.xml",
    title: None,
    description: None,
  )

  new_feed.title
  |> should.equal(None)
  
  new_feed.description
  |> should.equal(None)
}

pub fn feed_creation_test() {
  let test_feed = feed.Feed(
    id: Some(1),
    url: "https://example.com/feed.xml",
    title: "Test Feed",
    description: Some("Description"),
    added_at: "2025-10-19T12:00:00Z",
    last_checked: Some("2025-10-19T13:00:00Z"),
    is_active: True,
  )

  test_feed.id
  |> should.equal(Some(1))
  
  test_feed.url
  |> should.equal("https://example.com/feed.xml")
  
  test_feed.title
  |> should.equal("Test Feed")
  
  test_feed.is_active
  |> should.be_true
}

pub fn feed_metadata_creation_test() {
  let metadata = feed.FeedMetadata(
    title: "Feed Title",
    description: Some("Feed Description"),
  )

  metadata.title
  |> should.equal("Feed Title")
  
  metadata.description
  |> should.equal(Some("Feed Description"))
}

pub fn feed_error_types_test() {
  let err1 = feed.InvalidUrl("bad url")
  let err2 = feed.FetchFailed("network error")
  let err3 = feed.AlreadyExists
  let err4 = feed.NotFound
  let err5 = feed.DatabaseError("db error")

  err1
  |> should.equal(feed.InvalidUrl("bad url"))
  
  err2
  |> should.equal(feed.FetchFailed("network error"))
  
  err3
  |> should.equal(feed.AlreadyExists)
  
  err4
  |> should.equal(feed.NotFound)
  
  err5
  |> should.equal(feed.DatabaseError("db error"))
}
