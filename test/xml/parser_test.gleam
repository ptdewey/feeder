import gleam/list
import gleam/option.{None, Some}
import gleeunit/should
import xml/parser

pub fn parse_rss_feed_with_posts_test() {
  let xml =
    "<?xml version=\"1.0\" encoding=\"UTF-8\"?>
    <rss version=\"2.0\">
      <channel>
        <title>Test RSS Feed</title>
        <description>A test RSS feed</description>
        <item>
          <guid>post-1</guid>
          <title>First Post</title>
          <link>https://example.com/post-1</link>
          <description>Post description</description>
          <pubDate>2025-10-19T12:00:00Z</pubDate>
        </item>
        <item>
          <guid>post-2</guid>
          <title>Second Post</title>
          <link>https://example.com/post-2</link>
          <description>Another post</description>
          <pubDate>2025-10-18T10:00:00Z</pubDate>
        </item>
      </channel>
    </rss>"

  case parser.parse_feed(xml) {
    Ok(feed) -> {
      feed.title
      |> should.equal("Test RSS Feed")

      feed.description
      |> should.equal(Some("A test RSS feed"))

      list.length(feed.posts)
      |> should.equal(2)

      case list.first(feed.posts) {
        Ok(post) -> {
          post.guid
          |> should.equal("post-1")
          post.title
          |> should.equal("First Post")
          post.link
          |> should.equal("https://example.com/post-1")
          post.description
          |> should.equal(Some("Post description"))
          post.published_at
          |> should.equal(Some("2025-10-19T12:00:00Z"))
        }
        Error(_) -> should.fail()
      }
    }
    Error(_) -> should.fail()
  }
}

pub fn parse_atom_feed_with_entries_test() {
  let xml =
    "<?xml version=\"1.0\" encoding=\"UTF-8\"?>
    <feed xmlns=\"http://www.w3.org/2005/Atom\">
      <title>Test Atom Feed</title>
      <subtitle>An Atom test feed</subtitle>
      <entry>
        <id>atom-post-1</id>
        <title>First Atom Entry</title>
        <link href=\"https://example.com/atom-post-1\"/>
        <summary>Atom post summary</summary>
        <published>2025-10-19T10:00:00Z</published>
      </entry>
      <entry>
        <id>atom-post-2</id>
        <title>Second Atom Entry</title>
        <link href=\"https://example.com/atom-post-2\"/>
        <summary>Another Atom entry</summary>
        <content>Full content here</content>
        <published>2025-10-18T09:00:00Z</published>
      </entry>
    </feed>"

  case parser.parse_feed(xml) {
    Ok(feed) -> {
      feed.title
      |> should.equal("Test Atom Feed")

      feed.description
      |> should.equal(Some("An Atom test feed"))

      list.length(feed.posts)
      |> should.equal(2)

      case list.first(feed.posts) {
        Ok(entry) -> {
          entry.guid
          |> should.equal("atom-post-1")
          entry.title
          |> should.equal("First Atom Entry")
          entry.link
          |> should.equal("https://example.com/atom-post-1")
          entry.description
          |> should.equal(Some("Atom post summary"))
          entry.published_at
          |> should.equal(Some("2025-10-19T10:00:00Z"))
        }
        Error(_) -> should.fail()
      }
    }
    Error(_) -> should.fail()
  }
}

pub fn parse_rss_feed_minimal_post_test() {
  let xml =
    "<?xml version=\"1.0\" encoding=\"UTF-8\"?>
    <rss version=\"2.0\">
      <channel>
        <title>Minimal Feed</title>
        <item>
          <guid>minimal-1</guid>
          <title>Minimal Post</title>
          <link>https://example.com/minimal</link>
        </item>
      </channel>
    </rss>"

  case parser.parse_feed(xml) {
    Ok(feed) -> {
      list.length(feed.posts)
      |> should.equal(1)

      case list.first(feed.posts) {
        Ok(post) -> {
          post.guid
          |> should.equal("minimal-1")
          post.description
          |> should.equal(None)
          post.published_at
          |> should.equal(None)
        }
        Error(_) -> should.fail()
      }
    }
    Error(_) -> should.fail()
  }
}

pub fn parse_atom_feed_with_content_test() {
  let xml =
    "<?xml version=\"1.0\" encoding=\"UTF-8\"?>
    <feed xmlns=\"http://www.w3.org/2005/Atom\">
      <title>Content Test Feed</title>
      <entry>
        <id>content-1</id>
        <title>Entry with Content</title>
        <link href=\"https://example.com/content-1\"/>
        <content type=\"html\">&lt;p&gt;Rich HTML content&lt;/p&gt;</content>
        <published>2025-10-19T12:00:00Z</published>
      </entry>
    </feed>"

  case parser.parse_feed(xml) {
    Ok(feed) -> {
      case list.first(feed.posts) {
        Ok(entry) -> {
          entry.content
          |> should.equal(Some("<p>Rich HTML content</p>"))
        }
        Error(_) -> should.fail()
      }
    }
    Error(_) -> should.fail()
  }
}

pub fn parse_invalid_xml_test() {
  let xml = "not valid xml at all"

  parser.parse_feed(xml)
  |> should.be_error
}

pub fn parse_empty_rss_feed_test() {
  let xml =
    "<?xml version=\"1.0\" encoding=\"UTF-8\"?>
    <rss version=\"2.0\">
      <channel>
        <title>Empty Feed</title>
      </channel>
    </rss>"

  case parser.parse_feed(xml) {
    Ok(feed) -> {
      feed.title
      |> should.equal("Empty Feed")

      feed.posts
      |> should.equal([])
    }
    Error(_) -> should.fail()
  }
}

pub fn parse_empty_atom_feed_test() {
  let xml =
    "<?xml version=\"1.0\" encoding=\"UTF-8\"?>
    <feed xmlns=\"http://www.w3.org/2005/Atom\">
      <title>Empty Atom Feed</title>
    </feed>"

  case parser.parse_feed(xml) {
    Ok(feed) -> {
      feed.title
      |> should.equal("Empty Atom Feed")

      feed.posts
      |> should.equal([])
    }
    Error(_) -> should.fail()
  }
}

pub fn parse_atom_title_with_type_attribute_test() {
  let xml =
    "<?xml version=\"1.0\" encoding=\"UTF-8\"?>
    <feed xmlns=\"http://www.w3.org/2005/Atom\">
      <title type=\"html\">Test Feed with Type</title>
      <entry>
        <id>entry-1</id>
        <title type=\"html\">Entry Title</title>
        <link href=\"https://example.com/entry-1\"/>
        <summary type=\"html\">Summary text</summary>
        <published>2025-10-19T12:00:00Z</published>
      </entry>
    </feed>"

  case parser.parse_feed(xml) {
    Ok(feed) -> {
      feed.title
      |> should.equal("Test Feed with Type")

      case list.first(feed.posts) {
        Ok(entry) -> {
          entry.title
          |> should.equal("Entry Title")
          entry.description
          |> should.equal(Some("Summary text"))
        }
        Error(_) -> should.fail()
      }
    }
    Error(_) -> should.fail()
  }
}

pub fn parse_atom_content_with_cdata_test() {
  let xml =
    "<?xml version=\"1.0\" encoding=\"UTF-8\"?>
    <feed xmlns=\"http://www.w3.org/2005/Atom\">
      <title>CDATA Test Feed</title>
      <entry>
        <id>cdata-entry</id>
        <title type=\"html\"><![CDATA[CDATA Title]]></title>
        <link href=\"https://example.com/cdata\"/>
        <content type=\"html\"><![CDATA[<p>HTML content in CDATA</p>]]></content>
        <published>2025-10-19T12:00:00Z</published>
      </entry>
    </feed>"

  case parser.parse_feed(xml) {
    Ok(feed) -> {
      case list.first(feed.posts) {
        Ok(entry) -> {
          entry.title
          |> should.equal("CDATA Title")
          entry.content
          |> should.equal(Some("<p>HTML content in CDATA</p>"))
        }
        Error(_) -> should.fail()
      }
    }
    Error(_) -> should.fail()
  }
}

pub fn parse_rss_description_with_cdata_test() {
  let xml =
    "<?xml version=\"1.0\" encoding=\"UTF-8\"?>
    <rss version=\"2.0\">
      <channel>
        <title>RSS CDATA Test</title>
        <item>
          <guid>rss-cdata</guid>
          <title>RSS Item</title>
          <link>https://example.com/rss-cdata</link>
          <description><![CDATA[<p>Description with HTML</p>]]></description>
          <pubDate>2025-10-19T12:00:00Z</pubDate>
        </item>
      </channel>
    </rss>"

  case parser.parse_feed(xml) {
    Ok(feed) -> {
      case list.first(feed.posts) {
        Ok(post) -> {
          post.description
          |> should.equal(Some("<p>Description with HTML</p>"))
        }
        Error(_) -> should.fail()
      }
    }
    Error(_) -> should.fail()
  }
}
