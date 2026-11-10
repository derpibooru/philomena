defmodule Philomena.ArtistLinksFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `Philomena.ArtistLinks` context.
  """

  import Ecto.Query

  alias Philomena.{ArtistLinks, AttributionFixtures, ModerationLogs.ModerationLog, Repo}
  alias Philomena.ModerationLogs.Paths
  alias Philomena.UsersFixtures

  @doc """
  Creates an unverified artist link for `user` pointing at `tag` (which must
  be a creator-category tag - an `artist:`-prefixed `tag_fixture/1` name gets
  the `origin` category automatically).

  String-keyed attrs mirror the artist-link form (`"uri"`, `"public"`); a
  unique `"uri"` is supplied by default so repeated calls don't collide on
  the `[:uri, :tag_id, :user_id]` unique constraint.
  """
  def artist_link_fixture(user, tag, attrs \\ %{}) do
    attrs =
      Enum.into(attrs, %{
        "tag_name" => tag.name,
        "uri" => "https://example.com/artist#{System.unique_integer([:positive])}"
      })

    {:ok, {_user, artist_link}} =
      ArtistLinks.create_artist_link(AttributionFixtures.actor(user), user.slug, attrs)

    artist_link
  end

  @doc """
  Creates an artist link for `user`/`tag` and transitions it to the verified
  state through the moderator-facing context API. The badge awarder tolerates
  the missing "Artist" badge in tests.
  """
  def verified_artist_link_fixture(user, tag, attrs \\ %{}) do
    artist_link = artist_link_fixture(user, tag, attrs)
    moderator = UsersFixtures.moderator_user_fixture()

    {:ok, artist_link} =
      ArtistLinks.create_artist_link_verification(
        AttributionFixtures.actor(moderator),
        artist_link.id
      )

    subject_path = Paths.artist_link_path(user, artist_link)

    Repo.delete_all(
      from(log in ModerationLog,
        where:
          log.user_id == ^moderator.id and
            log.subject_path == ^subject_path
      )
    )

    artist_link
  end
end
