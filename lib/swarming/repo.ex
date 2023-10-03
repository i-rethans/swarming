defmodule Swarming.Repo do
  use Ecto.Repo,
    otp_app: :swarming,
    adapter: Ecto.Adapters.Postgres
end
