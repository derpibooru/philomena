defmodule Philomena.Repo.Migrations.UserStatisticsDayToDate do
  use Ecto.Migration

  def up do
    execute("alter table user_statistics alter column day drop default")

    execute(
      "alter table user_statistics alter column day type date using date '1970-01-01' + day"
    )
  end

  def down do
    execute(
      "alter table user_statistics alter column day type integer using day - date '1970-01-01'"
    )

    execute("alter table user_statistics alter column day set default 0")
  end
end
