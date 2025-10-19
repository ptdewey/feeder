import feeds/feed
import feeds/validator
import gleam/string
import gleeunit/should

pub fn validate_url_with_valid_https_url_test() {
  validator.validate_url("https://example.com/feed.xml")
  |> should.be_ok
}

pub fn validate_url_with_valid_http_url_test() {
  validator.validate_url("http://example.com/feed.xml")
  |> should.be_ok
}

pub fn validate_url_with_empty_string_test() {
  validator.validate_url("")
  |> should.equal(Error(feed.InvalidUrl("URL cannot be empty")))
}

pub fn validate_url_with_whitespace_only_test() {
  validator.validate_url("   ")
  |> should.equal(Error(feed.InvalidUrl("URL cannot be empty")))
}

pub fn validate_url_without_protocol_test() {
  validator.validate_url("example.com/feed.xml")
  |> should.equal(Error(feed.InvalidUrl("URL must start with http:// or https://")))
}

pub fn validate_url_with_invalid_protocol_test() {
  validator.validate_url("ftp://example.com/feed.xml")
  |> should.equal(Error(feed.InvalidUrl("URL must start with http:// or https://")))
}

pub fn validate_url_with_malformed_url_test() {
  validator.validate_url("https://not a valid url")
  |> should.equal(Error(feed.InvalidUrl("Malformed URL")))
}

pub fn validate_title_with_valid_title_test() {
  validator.validate_title("My RSS Feed")
  |> should.be_ok
}

pub fn validate_title_with_empty_string_test() {
  validator.validate_title("")
  |> should.equal(Error(feed.InvalidUrl("Title cannot be empty")))
}

pub fn validate_title_with_whitespace_only_test() {
  validator.validate_title("   ")
  |> should.equal(Error(feed.InvalidUrl("Title cannot be empty")))
}

pub fn validate_title_with_max_length_test() {
  let title = "a" <> string.repeat("x", 199)
  validator.validate_title(title)
  |> should.be_ok
}

pub fn validate_title_with_too_long_title_test() {
  let title = string.repeat("x", 201)
  validator.validate_title(title)
  |> should.equal(Error(feed.InvalidUrl("Title too long (max 200 characters)")))
}

pub fn validate_description_with_valid_description_test() {
  validator.validate_description("A great feed about technology")
  |> should.be_ok
}

pub fn validate_description_with_empty_string_test() {
  validator.validate_description("")
  |> should.be_ok
}

pub fn validate_description_with_max_length_test() {
  let description = string.repeat("x", 1000)
  validator.validate_description(description)
  |> should.be_ok
}

pub fn validate_description_with_too_long_description_test() {
  let description = string.repeat("x", 1001)
  validator.validate_description(description)
  |> should.equal(Error(feed.InvalidUrl("Description too long (max 1000 characters)")))
}
