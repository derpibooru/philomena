defmodule Philomena.Repo.Migrations.UniqueUserNameCaseInsensitive do
  use Ecto.Migration

  # Creating the index fails while users whose names differ only by letter
  # case exist. Run priv/repo/scripts/rename_case_variant_users.sql first.
  def change do
    create(unique_index(:users, ["lower(name)"], name: :index_users_on_lower_name))
  end
end
