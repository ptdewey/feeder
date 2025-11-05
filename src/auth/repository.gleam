import auth/user.{type AuthError, type User, User}
import gleam/dynamic/decode
import gleam/string
import sqlight.{type Connection}

pub fn create_user(db: Connection, user: User) -> Result(Nil, AuthError) {
  let query =
    "INSERT INTO users (username, password_hash) VALUES (?, ?)
    ON CONFLICT(username) DO UPDATE SET password_hash = excluded.password_hash"

  case
    sqlight.query(
      query,
      on: db,
      with: [sqlight.text(user.username), sqlight.text(user.password_hash)],
      expecting: decode.dynamic,
    )
  {
    Ok(_) -> Ok(Nil)
    Error(e) -> Error(user.DatabaseError(string.inspect(e)))
  }
}

pub fn get_user(db: Connection, username: String) -> Result(User, AuthError) {
  let query = "SELECT username, password_hash FROM users WHERE username = ?"

  let decoder = {
    use username <- decode.field(0, decode.string)
    use password_hash <- decode.field(1, decode.string)
    decode.success(User(username: username, password_hash: password_hash))
  }

  case
    sqlight.query(
      query,
      on: db,
      with: [sqlight.text(username)],
      expecting: decoder,
    )
  {
    Ok([user]) -> Ok(user)
    Ok([]) -> Error(user.UserNotFound)
    Ok(_) -> Error(user.UserNotFound)
    Error(e) -> Error(user.DatabaseError(string.inspect(e)))
  }
}

pub fn list_users(db: Connection) -> Result(List(String), AuthError) {
  let query = "SELECT username FROM users"

  let decoder = {
    use username <- decode.field(0, decode.string)
    decode.success(username)
  }

  case sqlight.query(query, on: db, with: [], expecting: decoder) {
    Ok(usernames) -> Ok(usernames)
    Error(e) -> Error(user.DatabaseError(string.inspect(e)))
  }
}
