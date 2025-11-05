import gleam/option.{type Option}

pub type ReadingListItem {
  ReadingListItem(
    id: Option(Int),
    url: String,
    title: String,
    description: Option(String),
    added_at: String,
  )
}

pub type ArchivedReadingListItem {
  ArchivedReadingListItem(
    id: Option(Int),
    url: String,
    title: String,
    description: Option(String),
    added_at: String,
    archived_at: String,
  )
}

pub type NewReadingListItem {
  NewReadingListItem(
    url: String,
    title: String,
    description: Option(String),
  )
}

pub type ReadingListError {
  NotFound
  AlreadyExists
  DatabaseError(String)
  InvalidUrl(String)
}
