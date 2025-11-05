import auth/session_store
import config
import database/migration
import envoy
import gleam/erlang/process
import mist
import sqlight
import web/router
import wisp
import wisp/wisp_mist

pub fn main() {
  wisp.configure_logger()

  let assert Ok(db) = sqlight.open("file:feeder.sqlite3")
  migration.run(db)

  let _ = config.load_users(db)
  let _ = config.load_initial_feeds(db)

  let assert Ok(session_store) = session_store.start()

  let secret_key_base = get_secret_key()

  let assert Ok(_) =
    router.handle_request(_, db, session_store)
    |> wisp_mist.handler(secret_key_base)
    |> mist.new
    |> mist.bind("0.0.0.0")
    |> mist.port(10_283)
    |> mist.start

  process.sleep_forever()
}

fn get_secret_key() -> String {
  case envoy.get("SECRET_KEY_BASE") {
    Ok(key) -> key
    Error(_) -> {
      wisp.log_warning(
        "SECRET_KEY_BASE not set, using random key. Set this in production!",
      )
      wisp.random_string(64)
    }
  }
}
