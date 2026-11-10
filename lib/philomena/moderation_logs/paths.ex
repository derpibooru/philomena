defmodule Philomena.ModerationLogs.Paths do
  @moduledoc """
  Builders for moderation-log `subject_path` strings.

  The values are plain data: each `subject_path` is stored as an opaque string
  in the `moderation_logs` table. Nothing verifies that they resolve to
  anything; they are simple, stable paths.

  ## Encoding

  Each dynamic segment runs through `Phoenix.Param.to_param/1` and then
  `URI.encode(segment, &URI.char_unreserved?/1)`. Slugs
  (`Philomena.Slug.slug/1`) can contain characters that are *not* URI-unreserved
  - notably `+` (from spaces) and escaped punctuation runs like `-dot-`,
  `-fwslash-` - so those bytes are percent-encoded. Integer ids and forum short
  names (`~r/\\A[a-z]+\\z/`) pass through unchanged, but are encoded the same way
  for uniformity.
  """

  alias Philomena.Images.Image
  alias Philomena.Tags.Tag
  alias Philomena.Users.User
  alias Philomena.Forums.Forum
  alias Philomena.Topics.Topic
  alias Philomena.Posts.Post
  alias Philomena.Reports.Report
  alias Philomena.DnpEntries.DnpEntry
  alias Philomena.ArtistLinks.ArtistLink

  @doc """
  Path to an image, e.g. `/images/123`.

  Accepts an `Image` struct or a raw image id (as used for a comment's
  `image_id`).
  """
  def image_path(%Image{id: id}), do: "/images/" <> encode_segment(id)
  def image_path(id) when is_integer(id), do: "/images/" <> encode_segment(id)

  @doc """
  Path to a comment on an image, e.g. `/images/123#comment_456`.
  """
  @spec image_comment_path(integer(), integer()) :: String.t()
  def image_comment_path(image_id, comment_id) do
    image_path(image_id) <> "#comment_" <> to_string(comment_id)
  end

  @doc """
  Path to a tag, e.g. `/tags/artist-colon-somebody`.
  """
  def tag_path(%Tag{slug: slug}), do: "/tags/" <> encode_segment(slug)

  @doc """
  Path to a user's profile, e.g. `/profiles/somebody`.
  """
  def profile_path(%User{slug: slug}), do: "/profiles/" <> encode_segment(slug)

  @doc """
  Path to a topic within its forum, e.g. `/forums/dis/topics/some-topic`.

  Accepts a `Topic` (whose `:forum` association must be loaded) or an explicit
  `Forum`/`Topic` pair.
  """
  def topic_path(%Topic{forum: %Forum{} = forum} = topic), do: topic_path(forum, topic)

  def topic_path(%Forum{short_name: short_name}, %Topic{slug: slug}) do
    "/forums/" <> encode_segment(short_name) <> "/topics/" <> encode_segment(slug)
  end

  @doc """
  Path to a specific post within a topic, e.g.
  `/forums/dis/topics/some-topic?post_id=456#post_456`.

  The post's `:topic` (and the topic's `:forum`) association must be loaded.
  """
  def forum_post_path(%Post{id: id, topic: %Topic{forum: %Forum{} = forum} = topic}) do
    topic_path(forum, topic) <> "?post_id=" <> to_string(id) <> "#post_" <> to_string(id)
  end

  @doc """
  Path to a DNP entry, e.g. `/dnp/123`.
  """
  def dnp_entry_path(%DnpEntry{id: id}), do: "/dnp/" <> encode_segment(id)

  @doc """
  Path to a report in the staff review interface, e.g. `/admin/reports/123`.

  Accepts a report or an already parsed report ID.
  """
  def admin_report_path(%Report{id: id}), do: admin_report_path(id)
  def admin_report_path(id) when is_integer(id), do: "/admin/reports/" <> encode_segment(id)

  @doc """
  Path to an artist link on a user's profile, e.g.
  `/profiles/somebody/artist_links/123`.

  Accepts the `User` and `ArtistLink`; the artist link's `:user` may also be
  passed via `artist_link_path/1` when loaded.
  """
  def artist_link_path(%User{} = user, %ArtistLink{id: id}) do
    profile_path(user) <> "/artist_links/" <> encode_segment(id)
  end

  def artist_link_path(%ArtistLink{user: %User{} = user} = artist_link) do
    artist_link_path(user, artist_link)
  end

  @doc """
  Path to an IP address profile, e.g. `/ip_profiles/203.0.113.1`.
  """
  @spec ip_profile_path(String.t()) :: String.t()
  def ip_profile_path(ip), do: "/ip_profiles/" <> encode_segment(ip)

  @doc """
  Path to a fingerprint profile, e.g. `/fingerprint_profiles/c1234567890`.
  """
  @spec fingerprint_profile_path(String.t()) :: String.t()
  def fingerprint_profile_path(fingerprint) do
    "/fingerprint_profiles/" <> encode_segment(fingerprint)
  end

  # Percent-encodes a path segment: `to_string/1` (equivalent to
  # `Phoenix.Param.to_param/1` for the integer ids and binary slugs used here)
  # followed by `URI.encode(&URI.char_unreserved?/1)`.
  @spec encode_segment(term()) :: String.t()
  defp encode_segment(segment) do
    segment
    |> to_string()
    |> URI.encode(&URI.char_unreserved?/1)
  end
end
