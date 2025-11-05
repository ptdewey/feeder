import auth/service
import auth/session_store
import auth/user.{UserCredentials}
import gleam/http
import gleam/int
import gleam/list
import gleam/option
import sqlight
import wisp.{type Request, type Response}

pub fn login(
  req: Request,
  db: sqlight.Connection,
  session_store: session_store.SessionStore,
) -> Response {
  use <- wisp.require_method(req, http.Post)
  use form <- wisp.require_form(req)

  let client_ip = get_client_ip(req)

  let username = list.key_find(form.values, "username") |> option.from_result
  let password = list.key_find(form.values, "password") |> option.from_result

  case username, password {
    option.Some(u), option.Some(p) -> {
      case session_store.check_lockout(session_store, client_ip) {
        session_store.Locked(seconds_remaining) -> {
          let minutes = seconds_remaining / 60 + 1
          wisp.redirect("/login?error=locked&minutes=" <> int.to_string(minutes))
        }
        session_store.NotLocked -> {
          let credentials = UserCredentials(username: u, password: p)
          case service.authenticate(db, credentials) {
            Ok(session) -> {
              session_store.reset_failed_attempts(session_store, client_ip)
              case session_store.store_session(session_store, session) {
                Ok(_) -> {
                  wisp.log_info("Login successful for user: " <> session.username)
                  wisp.redirect("/")
                  |> wisp.set_cookie(
                    req,
                    "session_token",
                    session.token,
                    wisp.Signed,
                    60 * 60 * 24 * 7,
                  )
                  |> wisp.set_cookie(
                    req,
                    "username",
                    session.username,
                    wisp.Signed,
                    60 * 60 * 24 * 7,
                  )
                }
                Error(_) -> {
                  wisp.log_error("Failed to store session for user: " <> u)
                  wisp.response(500)
                  |> wisp.string_body("Failed to create session")
                }
              }
            }
            Error(_) -> {
              session_store.record_failed_attempt(session_store, client_ip)
              wisp.redirect("/login?error=invalid")
            }
          }
        }
      }
    }
    _, _ -> wisp.bad_request("Missing username or password")
  }
}

fn get_client_ip(req: Request) -> String {
  case list.key_find(req.headers, "x-forwarded-for") {
    Ok(ip) -> ip
    Error(_) -> case list.key_find(req.headers, "x-real-ip") {
      Ok(ip) -> ip
      Error(_) -> "unknown"
    }
  }
}

pub fn logout(
  req: Request,
  session_store: session_store.SessionStore,
) -> Response {
  use <- wisp.require_method(req, http.Post)

  case wisp.get_cookie(req, "username", wisp.Signed) {
    Ok(username) -> {
      session_store.delete_session(session_store, username)
      wisp.redirect("/login")
      |> wisp.set_cookie(req, "session_token", "", wisp.Signed, 0)
      |> wisp.set_cookie(req, "username", "", wisp.Signed, 0)
    }
    Error(_) -> wisp.redirect("/login")
  }
}
