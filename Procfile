web: OBAN_QUEUES_ENV=OBAN_WEB MIX_ENV=prod elixir --sname server -S mix phx.server
worker: OBAN_QUEUES_ENV=OBAN_WORKER MIX_ENV=prod elixir --sname server -S mix phx.server
console: POOL_SIZE=2 iex -S mix
release: MIX_ENV=prod POOL_SIZE=2 mix ecto.migrate