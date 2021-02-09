defmodule Philomena.Repo.Migrations.AddBanDurationConstraints do
  use Ecto.Migration

  def change do
    create constraint("user_bans", "user_ban_duration_must_be_valid",
             check: "valid_until < '4000-01-01'"
           )

    create constraint("subnet_bans", "subnet_ban_duration_must_be_valid",
             check: "valid_until < '4000-01-01'"
           )

    create constraint("fingerprint_bans", "fingerprint_ban_duration_must_be_valid",
             check: "valid_until < '4000-01-01'"
           )
  end
end
