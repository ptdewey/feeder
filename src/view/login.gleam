import gleam/option.{type Option}
import nakai/attr
import nakai/html.{type Node}

pub fn render(error_msg: Option(String)) -> Node {
  html.Html([], [
    html.Head([
      html.meta([attr.charset("utf-8")]),
      html.meta([
        attr.name("viewport"),
        attr.content("width=device-width, initial-scale=1"),
      ]),
      html.title("Login - Feeder"),
      html.Element("style", [], [html.Text(
        "
        * {
          margin: 0;
          padding: 0;
          box-sizing: border-box;
        }

        body {
          font-family: Georgia, 'Times New Roman', serif;
          background: #e8dfc5;
          min-height: 100vh;
          display: flex;
          align-items: center;
          justify-content: center;
          color: #3d3428;
          line-height: 1.7;
        }

        .login-container {
          background: #f4ecd8;
          padding: 2rem;
          border-radius: 8px;
          box-shadow: 0 2px 4px rgba(61, 52, 40, 0.1);
          border: 1px solid #d4cdc0;
          width: 100%;
          max-width: 400px;
        }

        h1 {
          color: #5d4e37;
          margin-bottom: 1.5rem;
          text-align: center;
          font-size: 2rem;
        }

        .form-group {
          margin-bottom: 1rem;
        }

        label {
          display: block;
          color: #3d3428;
          font-weight: 500;
          margin-bottom: 0.5rem;
          font-size: 1.1rem;
        }

        input {
          width: 100%;
          padding: 0.75rem;
          border: 1px solid #d4cdc0;
          border-radius: 4px;
          font-size: 1.1rem;
          background: #f4ecd8;
          color: #3d3428;
          font-family: Georgia, 'Times New Roman', serif;
        }

        input:focus {
          outline: none;
          border-color: #a89074;
        }

        button {
          width: 100%;
          padding: 0.75rem;
          background: #a89074;
          color: #f4ecd8;
          border: none;
          border-radius: 4px;
          font-size: 1.1rem;
          font-weight: 500;
          cursor: pointer;
          font-family: Georgia, 'Times New Roman', serif;
        }

        button:hover {
          background: #8b7355;
        }

        button:active {
          background: #6b5d4f;
        }

        .error {
          background: #b5745a;
          color: #f4ecd8;
          padding: 1rem;
          border-radius: 4px;
          margin-bottom: 1rem;
          font-size: 1.1rem;
        }
      ")],
      ),
    ]),
    html.Body([], [
      html.div([attr.class("login-container")], [
        html.h1([], [html.Text("Login")]),
        case error_msg {
          option.Some(msg) ->
            html.div([attr.class("error")], [
              html.Text(msg),
            ])
          option.None -> html.Fragment([])
        },
        html.form([attr.method("POST"), attr.action("/auth/login")], [
          html.div([attr.class("form-group")], [
            html.label([attr.for("username")], [html.Text("Username")]),
            html.input([
              attr.id("username"),
              attr.name("username"),
              attr.type_("text"),
              attr.required(""),
              attr.Attr("autofocus", ""),
            ]),
          ]),
          html.div([attr.class("form-group")], [
            html.label([attr.for("password")], [html.Text("Password")]),
            html.input([
              attr.id("password"),
              attr.name("password"),
              attr.type_("password"),
              attr.required(""),
            ]),
          ]),
          html.button([attr.type_("submit")], [html.Text("Login")]),
        ]),
      ]),
    ]),
  ])
}
