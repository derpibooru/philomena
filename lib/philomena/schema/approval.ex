defmodule Philomena.Schema.Approval do
  import Ecto.Changeset

  @image_embed_regex ~r/!+\[/

  defp external_link_regex do
    site_domains =
      String.split(Application.get_env(:philomena, :site_domains), ",") ++
        [Application.get_env(:philomena, :cdn_host)]

    Regex.compile!(
      "https?\\\\?:(?:\\\\*\\/?)*(?!(?:#{Enum.map_join(site_domains, "|", &Regex.escape/1)}))"
    )
  end

  defp regex(:external_links), do: external_link_regex()
  defp regex(:image_embeds), do: @image_embed_regex

  defp trusted?(nil), do: false
  defp trusted?(user) when user.role != "user", do: true
  defp trusted?(user) when user.verified, do: true

  defp trusted?(user) do
    DateTime.diff(DateTime.utc_now(), user.created_at, :day) > 14
  end

  def approved?(_user, nil, _check), do: true
  def approved?(_user, "", _check), do: true

  def approved?(user, body, check) do
    trusted?(user) or not Regex.match?(regex(check), body)
  end

  def maybe_put_approval(
        %{changes: %{body: body}, valid?: true} = changeset,
        user,
        check
      ) do
    change(changeset, approved: approved?(user, body, check))
  end

  def maybe_put_approval(changeset, _user, _check), do: changeset
end
