defmodule Philomena.Repo do
  use Ecto.Repo,
    otp_app: :philomena,
    adapter: Ecto.Adapters.Postgres

  use Scrivener, page_size: 250

  # Database pagination accepts Scrivener's map or keyword inputs. Search owns
  # a narrower typed map because it applies its own defaults and page limits.
  @type pagination_params :: map() | keyword()
end
