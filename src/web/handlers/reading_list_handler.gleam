import gleam/int
import gleam/json
import gleam/list
import gleam/option
import reading_list/reading_list_item.{type ReadingListItem}
import reading_list/service
import sqlight.{type Connection}
import wisp.{type Request, type Response}

pub fn list(_req: Request, db: Connection) -> Response {
  case service.get_all_items(db) {
    Ok(items) -> {
      items
      |> list.map(item_to_json)
      |> json.array(of: fn(x) { x })
      |> json.to_string
      |> wisp.json_response(200)
    }
    Error(_) -> {
      json.object([#("error", json.string("Failed to fetch reading list"))])
      |> json.to_string
      |> wisp.json_response(500)
    }
  }
}

pub fn create(req: Request, db: Connection) -> Response {
  use form_data <- wisp.require_form(req)

  let url = list.key_find(form_data.values, "url")
  let title = list.key_find(form_data.values, "title")
  let description = list.key_find(form_data.values, "description")

  case url, title {
    Ok(url_val), Ok(title_val) -> {
      let new_item = reading_list_item.NewReadingListItem(
        url: url_val,
        title: title_val,
        description: case description {
          Ok("") -> option.None
          Ok(desc) -> option.Some(desc)
          Error(_) -> option.None
        },
      )

      case service.add_item(db, new_item) {
        Ok(_) -> wisp.redirect("/reading-list")
        Error(reading_list_item.InvalidUrl(msg)) -> {
          json.object([#("error", json.string(msg))])
          |> json.to_string
          |> wisp.json_response(400)
        }
        Error(reading_list_item.AlreadyExists) -> {
          json.object([#("error", json.string("Item already exists in reading list"))])
          |> json.to_string
          |> wisp.json_response(409)
        }
        Error(_) -> wisp.internal_server_error()
      }
    }
    _, _ -> wisp.bad_request("Missing required fields: url and title")
  }
}

pub fn archive(_req: Request, db: Connection, id: String) -> Response {
  case int.parse(id) {
    Ok(item_id) -> {
      case service.archive_item(db, item_id) {
        Ok(_) -> wisp.redirect("/reading-list")
        Error(reading_list_item.NotFound) -> wisp.not_found()
        Error(_) -> wisp.internal_server_error()
      }
    }
    Error(_) -> wisp.bad_request("Invalid item ID")
  }
}

fn item_to_json(item: ReadingListItem) -> json.Json {
  json.object([
    #("id", json.nullable(item.id, json.int)),
    #("url", json.string(item.url)),
    #("title", json.string(item.title)),
    #("description", json.nullable(item.description, json.string)),
    #("added_at", json.string(item.added_at)),
  ])
}
