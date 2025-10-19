[private]
default:
    @just --list

clean-run:
    @rm feeder.sqlite3 || true
    @gleam run

run:
    @gleam run

test:
    @gleam test
