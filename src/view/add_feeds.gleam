import gleam/list
import gleam/option
import nakai/attr
import nakai/html.{type Node}

pub fn render(error: option.Option(String)) -> Node {
  let error_html = case error {
    option.Some(msg) -> [html.div([attr.class("error")], [html.Text(msg)])]
    option.None -> []
  }

  html.Fragment(list.flatten([
    [html.h1([], [html.Text("Add New Feed")])],
    error_html,
    [
      html.div([attr.class("card")], [
        html.form([attr.method("POST"), attr.action("/feeds/new")], [
          html.div([attr.class("form-group")], [
            html.label([attr.for("url")], [html.Text("Feed URL")]),
            html.input([
              attr.type_("url"),
              attr.id("url"),
              attr.name("url"),
              attr.placeholder("https://example.com/feed.xml"),
              attr.required("required"),
            ]),
          ]),
          html.button([attr.type_("submit"), attr.class("btn")], [
            html.Text("Add Feed"),
          ]),
          html.a([attr.href("/feeds"), attr.style("margin-left: 1rem;")], [
            html.Text("Cancel"),
          ]),
        ]),
      ]),
    ],
  ]))
}
