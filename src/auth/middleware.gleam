import auth/session_store
import wisp.{type Request, type Response}

pub fn require_auth(
  req: Request,
  session_store: session_store.SessionStore,
  handler: fn(Request, String) -> Response,
) -> Response {
  case
    wisp.get_cookie(req, "username", wisp.Signed),
    wisp.get_cookie(req, "session_token", wisp.Signed)
  {
    Ok(username), Ok(token) -> {
      case session_store.get_session(session_store, username) {
        Ok(session) if session.token == token -> {
          wisp.log_info("Auth successful for: " <> username)
          handler(req, username)
        }
        Ok(_session) -> {
          wisp.log_warning("Token mismatch for user: " <> username)
          wisp.redirect("/login")
        }
        Error(_) -> {
          wisp.log_warning("Session not found for user: " <> username)
          wisp.redirect("/login")
        }
      }
    }
    Error(_), Ok(_) -> {
      wisp.log_warning("Username cookie missing")
      wisp.redirect("/login")
    }
    Ok(_), Error(_) -> {
      wisp.log_warning("Session token cookie missing")
      wisp.redirect("/login")
    }
    Error(_), Error(_) -> {
      wisp.log_info("No auth cookies present")
      wisp.redirect("/login")
    }
  }
}
