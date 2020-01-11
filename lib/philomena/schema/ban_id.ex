defmodule Philomena.Schema.BanId do
  import Ecto.Changeset

  def put_ban_id(%{data: %{generated_ban_id: nil}} = changeset, prefix) do
    ban_id = Base.encode16(:crypto.strong_rand_bytes(3))

    put_change(changeset, :generated_ban_id, "#{prefix}#{ban_id}")
  end

  def put_ban_id(changeset, _prefix), do: changeset
end
