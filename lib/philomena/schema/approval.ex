defmodule Philomena.Schema.Approval do
  import Ecto.Changeset

  @image_embed_regex ~r/!+\[/

  defp external_link_regex do
    site_domains =
      String.split(Application.get_env(:philomena, :site_domains), ",") ++
        [Application.get_env(:philomena, :cdn_host)]

    Regex.compile!(
      "https?\\\\?:(?:\\\\*\\/?)*+(?!(?:#{Enum.map_join(site_domains, "|", &Regex.escape/1)})(?::\\d+)?(?=[\\/?#\\s)\\]>\"'<]|$))",
      "i"
    )
  end

  defp regex(:external_links), do: external_link_regex()
  defp regex(:image_embeds), do: @image_embed_regex

  def trusted?(nil), do: false
  def trusted?(user) when user.role != "user", do: true
  def trusted?(user) when user.verified, do: true

  def trusted?(user) do
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
    was_approved? = fetch_field!(changeset, :approved)
    approved? = approved?(user, body, check)

    change(
      changeset,
      approved: approved?,
      became_unapproved?: was_approved? and not approved?
    )
  end

  def maybe_put_approval(changeset, _user, _check), do: changeset

  def approve_changeset(changeset) do
    if get_field(changeset, :approved) do
      add_error(changeset, :approved, "is already approved")
    else
      change(changeset, approved: true)
    end
  end
end
