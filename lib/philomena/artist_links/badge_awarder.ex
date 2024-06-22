defmodule Philomena.ArtistLinks.BadgeAwarder do
  @moduledoc """
  Handles awarding a badge to the user of an associated artist link.
  """

  alias Philomena.Badges

  @badge_title "Artist"

  @doc """
  Awards a badge to an artist with a verified link.

  If the badge with the title `"Artist"` does not exist, no award will be created.
  If the user already has an award with that badge title, no award will be created.

  Returns `{:ok, award}`, `{:ok, nil}`, or `{:error, changeset}`. The return value is
  suitable for use as the return value to an `Ecto.Multi.run/3` callback.
  """
  def award_badge(artist_link) do
    with badge when not is_nil(badge) <- Badges.get_badge_by_title(@badge_title),
         award when is_nil(award) <- Badges.get_badge_award_for(badge, artist_link.user) do
      Badges.create_badge_award(artist_link.user, artist_link.user)
    else
      _ ->
        {:ok, nil}
    end
  end
end
