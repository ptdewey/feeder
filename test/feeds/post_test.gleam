import feeds/post
import gleam/option.{None, Some}
import gleeunit/should

pub fn post_creation_test() {
  let test_post = post.Post(
    id: Some(1),
    feed_id: 10,
    guid: "post-guid-123",
    title: "Test Post",
    link: "https://example.com/post",
    description: Some("Post description"),
    content: Some("Full content"),
    published_at: Some("2025-10-19T12:00:00Z"),
    fetched_at: "2025-10-19T13:00:00Z",
  )

  test_post.id
  |> should.equal(Some(1))
  
  test_post.feed_id
  |> should.equal(10)
  
  test_post.guid
  |> should.equal("post-guid-123")
  
  test_post.title
  |> should.equal("Test Post")
  
  test_post.link
  |> should.equal("https://example.com/post")
}

pub fn new_post_creation_test() {
  let new_post = post.NewPost(
    feed_id: 5,
    guid: "new-post-guid",
    title: "New Post",
    link: "https://example.com/new-post",
    description: Some("Description"),
    content: None,
    published_at: Some("2025-10-19T10:00:00Z"),
  )

  new_post.feed_id
  |> should.equal(5)
  
  new_post.guid
  |> should.equal("new-post-guid")
  
  new_post.title
  |> should.equal("New Post")
  
  new_post.content
  |> should.equal(None)
}

pub fn new_post_with_all_none_optional_fields_test() {
  let new_post = post.NewPost(
    feed_id: 1,
    guid: "guid-456",
    title: "Minimal Post",
    link: "https://example.com/minimal",
    description: None,
    content: None,
    published_at: None,
  )

  new_post.description
  |> should.equal(None)
  
  new_post.content
  |> should.equal(None)
  
  new_post.published_at
  |> should.equal(None)
}
