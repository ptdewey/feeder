import gleam/dynamic/decode
import gleam/string
import reading_list/reading_list_item.{
  type ArchivedReadingListItem, type NewReadingListItem, type ReadingListError,
  type ReadingListItem,
}
import sqlight.{type Connection}

pub fn get_all(db: Connection) -> Result(List(ReadingListItem), ReadingListError) {
  let sql =
    "
    SELECT id, url, title, description, added_at
    FROM reading_list
    ORDER BY added_at DESC
  "

  case sqlight.query(sql, db, [], item_decoder()) {
    Ok(items) -> Ok(items)
    Error(_) -> Error(reading_list_item.DatabaseError("Failed to query reading list"))
  }
}

pub fn get_by_id(db: Connection, id: Int) -> Result(ReadingListItem, ReadingListError) {
  let sql =
    "
    SELECT id, url, title, description, added_at
    FROM reading_list 
    WHERE id = ?
    "

  case sqlight.query(sql, db, [sqlight.int(id)], item_decoder()) {
    Ok([item]) -> Ok(item)
    Ok([]) -> Error(reading_list_item.NotFound)
    Ok(_) -> Error(reading_list_item.DatabaseError("Multiple items found"))
    Error(_) -> Error(reading_list_item.DatabaseError("Query failed"))
  }
}

pub fn insert(db: Connection, new_item: NewReadingListItem) -> Result(ReadingListItem, ReadingListError) {
  let sql =
    "
    INSERT INTO reading_list (url, title, description, added_at)
    VALUES (?, ?, ?, datetime('now'))
    RETURNING id, url, title, description, added_at
    "

  let params = [
    sqlight.text(new_item.url),
    sqlight.text(new_item.title),
    sqlight.nullable(sqlight.text, new_item.description),
  ]

  case sqlight.query(sql, db, params, item_decoder()) {
    Ok([item]) -> Ok(item)
    Ok(_) -> Error(reading_list_item.DatabaseError("Insert failed"))
    Error(e) -> {
      case string.contains(string.inspect(e), "UNIQUE") {
        True -> Error(reading_list_item.AlreadyExists)
        False -> Error(reading_list_item.DatabaseError("Insert failed: " <> string.inspect(e)))
      }
    }
  }
}

pub fn archive(db: Connection, id: Int) -> Result(Nil, ReadingListError) {
  case get_by_id(db, id) {
    Ok(item) -> {
      let archive_sql =
        "
        INSERT INTO reading_list_archive (url, title, description, added_at, archived_at)
        VALUES (?, ?, ?, ?, datetime('now'))
        "

      let archive_params = [
        sqlight.text(item.url),
        sqlight.text(item.title),
        sqlight.nullable(sqlight.text, item.description),
        sqlight.text(item.added_at),
      ]

      case sqlight.query(archive_sql, db, archive_params, { decode.success(Nil) }) {
        Ok(_) -> {
          let delete_sql = "DELETE FROM reading_list WHERE id = ?"
          case sqlight.query(delete_sql, db, [sqlight.int(id)], { decode.success(Nil) }) {
            Ok(_) -> Ok(Nil)
            Error(_) -> Error(reading_list_item.DatabaseError("Delete failed"))
          }
        }
        Error(_) -> Error(reading_list_item.DatabaseError("Archive failed"))
      }
    }
    Error(e) -> Error(e)
  }
}

pub fn get_all_archived(db: Connection) -> Result(List(ArchivedReadingListItem), ReadingListError) {
  let sql =
    "
    SELECT id, url, title, description, added_at, archived_at
    FROM reading_list_archive
    ORDER BY archived_at DESC
  "

  case sqlight.query(sql, db, [], archived_item_decoder()) {
    Ok(items) -> Ok(items)
    Error(_) -> Error(reading_list_item.DatabaseError("Failed to query archived reading list"))
  }
}

fn item_decoder() -> decode.Decoder(ReadingListItem) {
  {
    use id <- decode.field(0, decode.optional(decode.int))
    use url <- decode.field(1, decode.string)
    use title <- decode.field(2, decode.string)
    use description <- decode.field(3, decode.optional(decode.string))
    use added_at <- decode.field(4, decode.string)

    decode.success(reading_list_item.ReadingListItem(
      id: id,
      url: url,
      title: title,
      description: description,
      added_at: added_at,
    ))
  }
}

fn archived_item_decoder() -> decode.Decoder(ArchivedReadingListItem) {
  {
    use id <- decode.field(0, decode.optional(decode.int))
    use url <- decode.field(1, decode.string)
    use title <- decode.field(2, decode.string)
    use description <- decode.field(3, decode.optional(decode.string))
    use added_at <- decode.field(4, decode.string)
    use archived_at <- decode.field(5, decode.string)

    decode.success(reading_list_item.ArchivedReadingListItem(
      id: id,
      url: url,
      title: title,
      description: description,
      added_at: added_at,
      archived_at: archived_at,
    ))
  }
}
