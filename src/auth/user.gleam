pub type User {
  User(username: String, password_hash: String)
}

pub type UserCredentials {
  UserCredentials(username: String, password: String)
}

pub type Session {
  Session(username: String, token: String)
}

pub type AuthError {
  InvalidCredentials
  UserNotFound
  DatabaseError(String)
  InvalidSession
}
