defmodule Philomena.Repo.Migrations.ConvertUserThemes do
  use Ecto.Migration

  def up do
    execute("update users set theme = 'light-blue' where theme = 'default';")
    execute("update users set theme = 'dark-blue' where theme = 'dark';")
    execute("update users set theme = 'dark-red' where theme = 'red';")
  end

  def down do
    execute("update users set theme = 'default' where theme like 'light%';")
    execute("update users set theme = 'red' where theme = 'dark-red';")
    execute("update users set theme = 'dark' where theme like 'dark%';")
  end
end
