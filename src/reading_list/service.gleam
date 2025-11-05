import gleam/string
import reading_list/reading_list_item.{
  type ArchivedReadingListItem, type NewReadingListItem, type ReadingListError,
  type ReadingListItem,
}
import reading_list/repository
import sqlight.{type Connection}

pub fn add_item(
  db: Connection,
  new_item: NewReadingListItem,
) -> Result(ReadingListItem, ReadingListError) {
  case validate_url(new_item.url) {
    Ok(_) -> repository.insert(db, new_item)
    Error(e) -> Error(e)
  }
}

pub fn get_all_items(
  db: Connection,
) -> Result(List(ReadingListItem), ReadingListError) {
  repository.get_all(db)
}

pub fn archive_item(db: Connection, id: Int) -> Result(Nil, ReadingListError) {
  repository.archive(db, id)
}

pub fn get_archived_items(
  db: Connection,
) -> Result(List(ArchivedReadingListItem), ReadingListError) {
  repository.get_all_archived(db)
}

fn validate_url(url: String) -> Result(Nil, ReadingListError) {
  let trimmed = string.trim(url)
  case string.is_empty(trimmed) {
    True -> Error(reading_list_item.InvalidUrl("URL cannot be empty"))
    False -> {
      case string.starts_with(trimmed, "http://") || string.starts_with(trimmed, "https://") {
        True -> Ok(Nil)
        False -> Error(reading_list_item.InvalidUrl("URL must start with http:// or https://"))
      }
    }
  }
}
