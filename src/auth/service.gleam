import auth/repository
import auth/user.{
  type AuthError, type Session, type UserCredentials, InvalidCredentials, Session,
  User,
}
import gleam/crypto
import gleam/string
import sqlight.{type Connection}
import wisp

pub fn hash_password(password: String) -> String {
  let password_bytes = <<password:utf8>>
  crypto.hash(crypto.Sha512, password_bytes)
  |> string.inspect
}

pub fn verify_password(password: String, hash: String) -> Bool {
  let computed = hash_password(password)
  crypto.secure_compare(<<computed:utf8>>, <<hash:utf8>>)
}

pub fn authenticate(
  db: Connection,
  credentials: UserCredentials,
) -> Result(Session, AuthError) {
  case repository.get_user(db, credentials.username) {
    Ok(user) -> {
      case verify_password(credentials.password, user.password_hash) {
        True -> {
          let token = wisp.random_string(64)
          Ok(Session(username: user.username, token: token))
        }
        False -> Error(InvalidCredentials)
      }
    }
    Error(e) -> Error(e)
  }
}

pub fn create_user_from_config(
  db: Connection,
  username: String,
  password: String,
) -> Result(Nil, AuthError) {
  let password_hash = hash_password(password)
  let user = User(username: username, password_hash: password_hash)
  repository.create_user(db, user)
}

pub fn validate_session(session: Session, expected_token: String) -> Bool {
  crypto.secure_compare(<<session.token:utf8>>, <<expected_token:utf8>>)
}
