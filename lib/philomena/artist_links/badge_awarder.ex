defmodule Philomena.ArtistLinks.BadgeAwarder do
  @moduledoc """
  Handles awarding a badge to the user of an associated artist link.
  """

  alias Philomena.Badges

  @doc """
  Awards a badge to a user.

  If the badge with the given title does not exist, no award will be created.
  If the user already has an award with that badge title, no award will be created.

  Returns `{:ok, award}`, `{:ok, nil}`, or `{:error, changeset}`. The return value is
  suitable for use as the return value to an `Ecto.Multi.run/3` callback.
  """
  def award_badge(user, verifying_user, title) do
    with badge when not is_nil(badge) <- Badges.get_badge_by_title(title),
         award when is_nil(award) <- Badges.get_badge_award_for(badge, user) do
      Badges.create_badge_award(verifying_user, user, %{badge_id: badge.id})
    else
      _ ->
        {:ok, nil}
    end
  end

  @doc """
  Get a callback for issuing a badge award from within an `m:Ecto.Multi`.
  """
  def award_callback(user, verifying_user, title) do
    fn _repo, _changes ->
      award_badge(user, verifying_user, title)
    end
  end
end
