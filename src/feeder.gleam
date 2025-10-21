import config
import database/migration
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

  let _ = config.load_initial_feeds(db)

  let secret_key_base = wisp.random_string(64)

  let assert Ok(_) =
    router.handle_request(_, db)
    |> wisp_mist.handler(secret_key_base)
    |> mist.new
    |> mist.bind("0.0.0.0")
    |> mist.port(10_283)
    |> mist.start

  process.sleep_forever()
}
