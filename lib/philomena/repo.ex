defmodule Philomena.Repo do
  use Ecto.Repo,
    otp_app: :philomena,
    adapter: Ecto.Adapters.Postgres
end
