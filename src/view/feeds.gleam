import feeds/feed
import gleam/int
import gleam/list
import gleam/option
import gleam/regexp
import gleam/string
import nakai/attr
import nakai/html.{type Node}

pub fn render(feeds: List(feed.Feed)) -> Node {
  html.Fragment([
    html.h1([], [html.Text("Your Feeds")]),
    html.div([attr.style("margin-bottom: 1rem;")], [
      html.a([attr.href("/feeds/new"), attr.class("btn")], [
        html.Text("Add New Feed"),
      ]),
      html.form(
        [
          attr.method("POST"),
          attr.action("/feeds/refresh"),
          attr.style("display: inline; margin-left: 0.5rem;"),
        ],
        [
          html.button(
            [
              attr.type_("submit"),
              attr.class("btn"),
              attr.style("background: #27ae60;"),
            ],
            [html.Text("Refresh All Feeds")],
          ),
        ],
      ),
    ]),
    html.div([attr.class("card")], case feeds {
      [] -> [html.p([], [html.Text("No feeds yet. Add one to get started!")])]
      _ ->
        list.map(feeds, fn(f) {
          let description = case f.description {
            option.Some(desc) -> [
              html.p([attr.class("feed-url")], [html.Text(truncate(desc, 200))]),
            ]
            option.None -> []
          }
          let last_checked = case f.last_checked {
            option.Some(checked) -> "Last checked: " <> format_date(checked)
            option.None -> "Never checked"
          }
          let id_str = case f.id {
            option.Some(id) -> int.to_string(id)
            option.None -> "0"
          }
           html.div(
             [attr.class("feed-item")],
             list.flatten([
               [
                 html.div([attr.class("feed-title")], [
                   html.a([attr.href("/feeds/" <> id_str <> "/posts")], [
                     html.Text(f.title),
                   ]),
                 ]),
                 html.p([attr.class("feed-url")], [html.Text(f.url)]),
               ],
               description,
               [
                 html.p([attr.class("post-meta")], [html.Text(last_checked)]),
                 html.form(
                   [
                     attr.method("POST"),
                     attr.action("/feeds/" <> id_str <> "/refresh"),
                     attr.style("display: inline;"),
                   ],
                   [
                     html.button(
                       [
                         attr.type_("submit"),
                         attr.class("btn"),
                         attr.style("font-size: 0.9rem; padding: 0.5rem 1rem;"),
                       ],
                       [html.Text("Refresh")],
                     ),
                   ],
                 ),
               ],
             ]),
           )
        })
    }),
  ])
}

fn truncate(text: String, max_chars: Int) -> String {
  let clean_text = strip_html(text)
  case string.length(clean_text) > max_chars {
    True -> string.slice(clean_text, 0, max_chars) <> "..."
    False -> clean_text
  }
}

fn strip_html(text: String) -> String {
  let assert Ok(tag_regex) = regexp.from_string("<[^>]+>")

  text
  |> regexp.replace(tag_regex, _, "")
  |> decode_html_entities()
  |> string.trim()
}

fn decode_html_entities(text: String) -> String {
  text
  |> string.replace("&nbsp;", " ")
  |> string.replace("&amp;", "&")
  |> string.replace("&lt;", "<")
  |> string.replace("&gt;", ">")
  |> string.replace("&quot;", "\"")
  |> string.replace("&#39;", "'")
  |> string.replace("&apos;", "'")
}

fn format_date(date_str: String) -> String {
  case string.split(date_str, " ") {
    [_day, day_num, month, year, ..] -> day_num <> " " <> month <> " " <> year
    _ -> date_str
  }
}
