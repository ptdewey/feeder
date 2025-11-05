import gleam/int
import gleam/list
import gleam/option
import gleam/string
import nakai/attr
import nakai/html.{type Node}
import reading_list/reading_list_item

pub fn render(items: List(reading_list_item.ReadingListItem)) -> Node {
  html.Fragment([
    html.h1([], [html.Text("Reading List")]),
    html.div([attr.style("margin-bottom: 2rem;")], [
      html.div([attr.class("card")], [
        html.h2([attr.style("margin-top: 0;")], [html.Text("Add a Link")]),
        html.form(
          [
            attr.method("POST"),
            attr.action("/api/reading-list"),
            attr.id("add-link-form"),
          ],
          [
            html.div([attr.style("margin-bottom: 1rem;")], [
              html.label([attr.for("url")], [html.Text("URL")]),
              html.input([
                attr.type_("url"),
                attr.id("url"),
                attr.name("url"),
                attr.placeholder("https://example.com/article"),
                attr.Attr("required", ""),
                attr.style("width: 100%; padding: 0.5rem; margin-top: 0.25rem;"),
              ]),
            ]),
            html.div([attr.style("margin-bottom: 1rem;")], [
              html.label([attr.for("title")], [html.Text("Title")]),
              html.input([
                attr.type_("text"),
                attr.id("title"),
                attr.name("title"),
                attr.placeholder("Article Title"),
                attr.Attr("required", ""),
                attr.style("width: 100%; padding: 0.5rem; margin-top: 0.25rem;"),
              ]),
            ]),
            html.div([attr.style("margin-bottom: 1rem;")], [
              html.label([attr.for("description")], [html.Text("Description (optional)")]),
              html.textarea(
                [
                  attr.id("description"),
                  attr.name("description"),
                  attr.placeholder("Brief description of the link"),
                  attr.style("width: 100%; padding: 0.5rem; margin-top: 0.25rem; min-height: 80px;"),
                ],
                [html.Text("")],
              ),
            ]),
            html.button(
              [attr.type_("submit"), attr.class("btn")],
              [html.Text("Add to Reading List")],
            ),
          ],
        ),
      ]),
    ]),
    html.h2([], [html.Text("Your Reading List")]),
    html.div([attr.class("card")], case items {
      [] -> [html.p([], [html.Text("No items in your reading list yet. Add one above!")])]
      _ ->
        list.map(items, fn(item) {
          let description = case item.description {
            option.Some(desc) -> [
              html.p([attr.class("post-meta")], [html.Text(desc)]),
            ]
            option.None -> []
          }
          let id_str = case item.id {
            option.Some(id) -> int.to_string(id)
            option.None -> "0"
          }
          html.div(
            [attr.class("feed-item item-with-action")],
            [
              html.div([attr.class("item-content")], list.flatten([
                [
                  html.div([attr.class("feed-title")], [
                    html.a([attr.href(item.url), attr.target("_blank"), attr.rel("noopener noreferrer")], [
                      html.Text(item.title),
                    ]),
                  ]),
                  html.p([attr.class("feed-url")], [html.Text(item.url)]),
                ],
                description,
                [
                  html.p([attr.class("post-meta")], [html.Text("Added: " <> format_date(item.added_at))]),
                ],
              ])),
              html.div([attr.class("item-action")], [
                html.form(
                  [
                    attr.method("POST"),
                    attr.action("/api/reading-list/" <> id_str <> "/archive"),
                  ],
                  [
                    html.button(
                      [
                        attr.type_("submit"),
                        attr.class("btn"),
                        attr.style("background-color: #dc3545; font-size: 0.9rem; padding: 0.5rem 1rem;"),
                      ],
                      [html.Text("Remove")],
                    ),
                  ],
                ),
              ]),
            ],
          )
        })
    }),
  ])
}

fn format_date(date_str: String) -> String {
  let date_part = case string.split(date_str, "T") {
    [date, _] -> date
    _ -> case string.split(date_str, " ") {
      [date, _] -> date
      _ -> date_str
    }
  }
  
  case string.split(date_part, "-") {
    [year, month, day] -> {
      let month_name = case month {
        "01" -> "Jan"
        "02" -> "Feb"
        "03" -> "Mar"
        "04" -> "Apr"
        "05" -> "May"
        "06" -> "Jun"
        "07" -> "Jul"
        "08" -> "Aug"
        "09" -> "Sep"
        "10" -> "Oct"
        "11" -> "Nov"
        "12" -> "Dec"
        _ -> month
      }
      let day_num = case string.starts_with(day, "0") {
        True -> string.slice(day, 1, 1)
        False -> day
      }
      month_name <> " " <> day_num <> ", " <> year
    }
    _ -> date_str
  }
}
