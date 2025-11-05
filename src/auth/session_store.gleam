import auth/user.{type Session}
import gleam/dict.{type Dict}
import gleam/erlang/process.{type Subject}

pub opaque type SessionStore {
  SessionStore(dict: Subject(Message))
}

pub type LockoutStatus {
  NotLocked
  Locked(seconds_remaining: Int)
}

type FailedAttempt {
  FailedAttempt(count: Int, locked_until: Int)
}

type Message {
  Get(username: String, reply: Subject(Result(Session, Nil)))
  Set(username: String, session: Session, reply: Subject(Nil))
  Delete(username: String, reply: Subject(Nil))
  RecordFailure(ip: String, reply: Subject(Nil))
  CheckLockout(ip: String, reply: Subject(LockoutStatus))
  ResetFailures(ip: String, reply: Subject(Nil))
}

type State {
  State(sessions: Dict(String, Session), failed_attempts: Dict(String, FailedAttempt))
}

pub fn start() -> Result(SessionStore, Nil) {
  let reply_subject = process.new_subject()
  let _ = process.spawn(fn() { 
    let subject = process.new_subject()
    process.send(reply_subject, subject)
    loop(State(sessions: dict.new(), failed_attempts: dict.new()), subject)
  })
  case process.receive(reply_subject, 5000) {
    Ok(subject) -> Ok(SessionStore(dict: subject))
    Error(_) -> Error(Nil)
  }
}

fn loop(state: State, subject: Subject(Message)) -> Nil {
  case process.receive(subject, 60_000) {
    Ok(Get(username, reply)) -> {
      case dict.get(state.sessions, username) {
        Ok(session) -> process.send(reply, Ok(session))
        Error(_) -> process.send(reply, Error(Nil))
      }
      loop(state, subject)
    }
    Ok(Set(username, session, reply)) -> {
      let new_sessions = dict.insert(state.sessions, username, session)
      process.send(reply, Nil)
      loop(State(..state, sessions: new_sessions), subject)
    }
    Ok(Delete(username, reply)) -> {
      let new_sessions = dict.delete(state.sessions, username)
      process.send(reply, Nil)
      loop(State(..state, sessions: new_sessions), subject)
    }
    Ok(RecordFailure(ip, reply)) -> {
      let current_time = get_current_timestamp()
      let new_attempts = case dict.get(state.failed_attempts, ip) {
        Ok(attempt) -> {
          case attempt.locked_until > current_time {
            True -> state.failed_attempts
            False -> {
              let new_count = attempt.count + 1
              case new_count >= 5 {
                True -> {
                  let locked_until = current_time + 900
                  dict.insert(state.failed_attempts, ip, FailedAttempt(count: new_count, locked_until: locked_until))
                }
                False -> {
                  dict.insert(state.failed_attempts, ip, FailedAttempt(count: new_count, locked_until: 0))
                }
              }
            }
          }
        }
        Error(_) -> {
          dict.insert(state.failed_attempts, ip, FailedAttempt(count: 1, locked_until: 0))
        }
      }
      process.send(reply, Nil)
      loop(State(..state, failed_attempts: new_attempts), subject)
    }
    Ok(CheckLockout(ip, reply)) -> {
      let current_time = get_current_timestamp()
      let status = case dict.get(state.failed_attempts, ip) {
        Ok(attempt) -> {
          case attempt.locked_until > current_time {
            True -> Locked(seconds_remaining: attempt.locked_until - current_time)
            False -> NotLocked
          }
        }
        Error(_) -> NotLocked
      }
      process.send(reply, status)
      loop(state, subject)
    }
    Ok(ResetFailures(ip, reply)) -> {
      let new_attempts = dict.delete(state.failed_attempts, ip)
      process.send(reply, Nil)
      loop(State(..state, failed_attempts: new_attempts), subject)
    }
    Error(_) -> loop(state, subject)
  }
}

@external(erlang, "erlang", "system_time")
fn erlang_system_time(unit: Int) -> Int

fn get_current_timestamp() -> Int {
  erlang_system_time(1)
}

pub fn store_session(
  store: SessionStore,
  session: Session,
) -> Result(Nil, Nil) {
  let reply = process.new_subject()
  process.send(store.dict, Set(session.username, session, reply))
  case process.receive(reply, 5000) {
    Ok(_) -> Ok(Nil)
    Error(_) -> Error(Nil)
  }
}

pub fn get_session(
  store: SessionStore,
  username: String,
) -> Result(Session, Nil) {
  let reply = process.new_subject()
  process.send(store.dict, Get(username, reply))
  case process.receive(reply, 5000) {
    Ok(result) -> result
    Error(_) -> Error(Nil)
  }
}

pub fn delete_session(store: SessionStore, username: String) -> Nil {
  let reply = process.new_subject()
  process.send(store.dict, Delete(username, reply))
  case process.receive(reply, 5000) {
    Ok(result) -> result
    Error(_) -> Nil
  }
}

pub fn clear_sessions(_store: SessionStore) -> Nil {
  Nil
}

pub fn record_failed_attempt(store: SessionStore, ip: String) -> Nil {
  let reply = process.new_subject()
  process.send(store.dict, RecordFailure(ip, reply))
  case process.receive(reply, 5000) {
    Ok(result) -> result
    Error(_) -> Nil
  }
}

pub fn check_lockout(store: SessionStore, ip: String) -> LockoutStatus {
  let reply = process.new_subject()
  process.send(store.dict, CheckLockout(ip, reply))
  case process.receive(reply, 5000) {
    Ok(result) -> result
    Error(_) -> NotLocked
  }
}

pub fn reset_failed_attempts(store: SessionStore, ip: String) -> Nil {
  let reply = process.new_subject()
  process.send(store.dict, ResetFailures(ip, reply))
  case process.receive(reply, 5000) {
    Ok(result) -> result
    Error(_) -> Nil
  }
}
