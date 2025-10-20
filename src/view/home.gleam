import feeds/post
import gleam/list
import gleam/option
import gleam/regexp
import gleam/string
import nakai/attr
import nakai/html.{type Node}

pub fn render(posts: List(post.Post)) -> Node {
  html.Fragment([
    html.h1([], [html.Text("Recent Posts")]),
    html.form(
      [
        attr.method("POST"),
        attr.action("/feeds/refresh"),
        attr.style("margin-bottom: 1rem;"),
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
    html.div([attr.class("card")], case posts {
      [] -> [
        html.p([], [
          html.Text("No posts yet. Add some feeds to get started!"),
        ]),
      ]
      _ ->
        list.map(posts, fn(p) {
          let description = case p.description {
            option.Some(desc) -> [
              html.p([attr.class("post-meta")], [
                html.Text(truncate(desc, 200)),
              ]),
            ]
            option.None -> []
          }
           let date = case p.published_at {
             option.Some(published) -> published
             option.None -> p.fetched_at
           }
           let link = normalize_link(p.link)
           html.div(
             [attr.class("post-item")],
             list.flatten([
               [
                 html.div([attr.class("post-title")], [
                   html.a([attr.href(link), attr.target("_blank")], [
                     html.Text(p.title),
                   ]),
                  html.Text(" "),
                  html.span(
                    [
                      attr.style(
                        "color: #999; font-style: italic; font-size: 0.9rem;",
                      ),
                    ],
                    [
                      html.Text(format_date(date)),
                    ],
                  ),
                ]),
              ],
              description,
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

fn normalize_link(link: String) -> String {
  case string.starts_with(link, "http://") || string.starts_with(link, "https://") {
    True -> link
    False -> "https://" <> link
  }
}
