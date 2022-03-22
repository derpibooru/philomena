defmodule Philomena.Schema.Approval do
  alias Philomena.Users.User
  import Ecto.Changeset

  @image_embed_regex ~r/!+\[/

  def maybe_put_approval(changeset, nil),
    do: change(changeset, approved: true)

  def maybe_put_approval(changeset, %{role: role})
      when role != "user",
      do: change(changeset, approved: true)

  def maybe_put_approval(
        %{changes: %{body: body}, valid?: true} = changeset,
        %User{} = user
      ) do
    now = now_time()
    # 14 * 24 * 60 * 60
    two_weeks = 1_209_600

    case String.match?(body, @image_embed_regex) do
      true ->
        case DateTime.compare(now, DateTime.add(user.created_at, two_weeks)) do
          :gt -> change(changeset, approved: true)
          _ -> change(changeset, approved: false)
        end

      _ ->
        change(changeset, approved: true)
    end
  end

  def maybe_put_approval(changeset, _user), do: changeset

  def maybe_strip_images(
        %{changes: %{body: body}, valid?: true} = changeset,
        nil
      ),
      do: change(changeset, body: Regex.replace(@image_embed_regex, body, "["))

  def maybe_strip_images(changeset, _user), do: changeset

  defp now_time(), do: DateTime.truncate(DateTime.utc_now(), :second)
end
