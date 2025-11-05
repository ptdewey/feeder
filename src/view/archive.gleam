import gleam/list
import gleam/option
import gleam/string
import nakai/attr
import nakai/html.{type Node}
import reading_list/reading_list_item

pub fn render(items: List(reading_list_item.ArchivedReadingListItem)) -> Node {
  html.Fragment([
    html.h1([], [html.Text("Reading List Archive")]),
    html.div([attr.class("card")], case items {
      [] -> [html.p([], [html.Text("No archived items yet.")])]
      _ ->
        list.map(items, fn(item) {
          let description = case item.description {
            option.Some(desc) -> [
              html.p([attr.class("post-meta")], [html.Text(desc)]),
            ]
            option.None -> []
          }
          html.div(
            [attr.class("feed-item")],
            list.flatten([
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
                html.p([attr.class("post-meta")], [
                  html.Text("Added: " <> format_date(item.added_at) <> " | Archived: " <> format_date(item.archived_at)),
                ]),
              ],
            ]),
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
