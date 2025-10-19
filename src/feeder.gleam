import database/migration
import gleam/erlang/process
import mist
import sqlight
import web/router
import wisp
import wisp/wisp_mist

pub fn main() {
  // Initialize logging
  wisp.configure_logger()

  // Initialize database
  let assert Ok(db) = sqlight.open("file:feeder.sqlite3")
  migration.run(db)

  // Start web server
  let port = 8000
  let secret_key_base = wisp.random_string(64)

  let assert Ok(_) =
    router.handle_request(_, db)
    |> wisp_mist.handler(secret_key_base)
    |> mist.new
    |> mist.port(port)
    |> mist.start

  process.sleep_forever()
}
