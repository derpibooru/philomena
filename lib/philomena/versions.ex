defmodule Philomena.Versions do
  @moduledoc """
  The Versions context.
  """

  import Ecto.Query, warn: false
  alias Philomena.Repo

  alias Philomena.Versions.Version
  alias Philomena.Users.User

  def load_data_and_associations(versions, parent) do
    user_ids =
      versions
      |> Enum.map(& &1.whodunnit)
      |> Enum.reject(&is_nil/1)

    users =
      User
      |> where([u], u.id in ^user_ids)
      |> preload(awards: :badge)
      |> Repo.all()
      |> Map.new(&{to_string(&1.id), &1})

    {versions, _last_body} =
      versions
      |> Enum.map_reduce(
        {parent.body, parent.edit_reason},
        fn version, {previous_body, previous_reason} ->
          yaml = YamlElixir.read_from_string!(version.object || "")
          body = yaml["body"] || ""
          edit_reason = yaml["edit_reason"]

          v = %{
            version
            | parent: parent,
              user: users[version.whodunnit],
              body: body,
              edit_reason: previous_reason,
              difference: difference(body, previous_body)
          }

          {v, {body, edit_reason}}
        end
      )

    versions
  end

  defp difference(previous, nil), do: [eq: previous]
  defp difference(previous, next), do: String.myers_difference(previous, next)

  @doc """
  Creates a version.

  ## Examples

      iex> create_version(%{field: value})
      {:ok, %Version{}}

      iex> create_version(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_version(item_type, item_id, whodunnit, attrs \\ %{}) do
    %Version{
      item_type: item_type,
      item_id: item_id,
      event: "update",
      whodunnit: whodunnit(whodunnit)
    }
    |> Version.changeset(attrs, item_id)
    |> Repo.insert()
  end

  # revolver ocelot
  defp whodunnit(user_id) when is_integer(user_id), do: to_string(user_id)
  defp whodunnit(nil), do: nil
end
