defmodule Philomena.Profiles.ProfilePage do
  @moduledoc """
  Everything a user's public profile holds for one viewer: the user with its
  profile associations, the recent uploads/faves/artwork image strips, the
  viewer's interactions across them, the recent comments and posts, recent
  galleries, the 90-day statistics series, watcher counts for the user's
  verified-link tags, the user's public-link tags, and the user's bans.

  `recent_comments` holds only the comments whose images the viewer may see.
  The loaded user carries its forced filter for the existing owner/staff-only
  presentation gate.
  Descriptions, comment bodies, and commission text are carried raw;
  processing them is the caller's concern.
  """

  alias Philomena.Users.User

  @enforce_keys [
    :user,
    :recent_uploads,
    :recent_faves,
    :recent_artwork,
    :recent_comments,
    :recent_posts,
    :recent_galleries,
    :statistics,
    :watcher_counts,
    :tags,
    :interactions,
    :bans
  ]
  defstruct [
    :user,
    :recent_uploads,
    :recent_faves,
    :recent_artwork,
    :recent_comments,
    :recent_posts,
    :recent_galleries,
    :statistics,
    :watcher_counts,
    :tags,
    :interactions,
    :bans
  ]

  @type t :: %__MODULE__{
          user: User.t(),
          recent_uploads: Scrivener.Page.t(),
          recent_faves: Scrivener.Page.t(),
          recent_artwork: Scrivener.Page.t(),
          recent_comments: list(),
          recent_posts: list(),
          recent_galleries: list(),
          statistics: map(),
          watcher_counts: map(),
          tags: list(),
          interactions: list(),
          bans: list()
        }
end
