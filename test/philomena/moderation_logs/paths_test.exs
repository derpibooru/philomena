defmodule Philomena.ModerationLogs.PathsTest do
  @moduledoc """
  Pins that `Philomena.ModerationLogs.Paths` produces identical strings to
  the `~p` (VerifiedRoutes) forms controllers build for moderation-log
  `subject_path` values.

  The high-value assertion is equality against `~p` for the exact
  `subject_path` interpolations used in `lib/philomena_web/controllers`, using
  slugs/short_names/ips whose characters need percent-encoding (`+` from a
  space, `&`, `?`, `:` in IPv6) so a divergence in `Paths`' hand-rolled encoding
  from Phoenix's would fail here. Structs are built in memory: `Phoenix.Param`
  only reads the derived key (`:id`, `:slug`, `:short_name`), so no DB row is
  needed.
  """

  use ExUnit.Case, async: true
  use PhilomenaWeb, :verified_routes

  alias Philomena.ModerationLogs.Paths
  alias Philomena.Slug

  alias Philomena.Images.Image
  alias Philomena.Tags.Tag
  alias Philomena.Users.User
  alias Philomena.Forums.Forum
  alias Philomena.Topics.Topic
  alias Philomena.Posts.Post
  alias Philomena.Reports.Report
  alias Philomena.DnpEntries.DnpEntry
  alias Philomena.ArtistLinks.ArtistLink

  # A tag slug exercising the interesting escapes: `-colon-` (from `:`) and,
  # crucially for the encoding, `+` (from a space), `&`, and `?` - none of which
  # are URI-unreserved, so `~p` percent-encodes them and `Paths` must match.
  defp interesting_tag_slug, do: Slug.slug("artist:my cool & art?")
  # slug/1: "artist-colon-my+cool+&+art?"

  # A topic slug that contains a `-dash-` escape plus a `+` (space) and `!`.
  defp interesting_topic_slug, do: Slug.slug("Time-Wasting Thread!")
  # slug/1: "Time-dash-Wasting+Thread!"

  defp interesting_user_slug, do: Slug.slug("Cool User & Co")
  # slug/1: "Cool+User+&+Co"

  describe "image_path/1" do
    test "matches ~p for an Image struct" do
      image = %Image{id: 123}
      assert Paths.image_path(image) == ~p"/images/#{image}"
      assert Paths.image_path(image) == "/images/123"
    end

    test "matches ~p for a raw integer id (as used for comment.image_id)" do
      assert Paths.image_path(123) == ~p"/images/#{123}"
    end
  end

  describe "image_comment_path/2" do
    test "matches the comment-anchor form controllers build" do
      # ~p"/images/#{comment.image_id}" <> "#comment_#{comment.id}"
      assert Paths.image_comment_path(123, 456) == ~p"/images/#{123}" <> "#comment_456"
      assert Paths.image_comment_path(123, 456) == "/images/123#comment_456"
    end
  end

  describe "tag_path/1" do
    test "matches ~p for a slug needing percent-encoding" do
      tag = %Tag{slug: interesting_tag_slug()}
      assert Paths.tag_path(tag) == ~p"/tags/#{tag}"
    end

    test "encodes +, &, and ? the same way Phoenix does" do
      tag = %Tag{slug: interesting_tag_slug()}
      # `+`→%2B, `&`→%26, `?`→%3F; `-colon-` is all unreserved and passes through.
      assert Paths.tag_path(tag) == "/tags/artist-colon-my%2Bcool%2B%26%2Bart%3F"
    end
  end

  describe "profile_path/1" do
    test "matches ~p (User derives Phoenix.Param from :slug)" do
      user = %User{slug: interesting_user_slug()}
      assert Paths.profile_path(user) == ~p"/profiles/#{user}"
    end
  end

  describe "topic_path/1 and topic_path/2" do
    test "topic_path/2 matches ~p (Forum → :short_name, Topic → :slug)" do
      forum = %Forum{short_name: "dis"}
      topic = %Topic{slug: interesting_topic_slug()}
      assert Paths.topic_path(forum, topic) == ~p"/forums/#{forum}/topics/#{topic}"
    end

    test "topic_path/1 uses the topic's loaded :forum association" do
      forum = %Forum{short_name: "dis"}
      topic = %Topic{slug: interesting_topic_slug(), forum: forum}
      assert Paths.topic_path(topic) == ~p"/forums/#{forum}/topics/#{topic}"
      assert Paths.topic_path(topic) == Paths.topic_path(forum, topic)
    end
  end

  describe "forum_post_path/1" do
    test "matches the post-anchor form controllers build" do
      forum = %Forum{short_name: "dis"}
      topic = %Topic{slug: interesting_topic_slug(), forum: forum}
      post = %Post{id: 456, topic: topic}

      # ~p"/forums/#{forum}/topics/#{topic}?#{[post_id: post.id]}" <> "#post_#{post.id}"
      expected = ~p"/forums/#{forum}/topics/#{topic}?#{[post_id: 456]}" <> "#post_456"
      assert Paths.forum_post_path(post) == expected
    end
  end

  describe "dnp_entry_path/1" do
    test "matches ~p (DnpEntry derives Phoenix.Param from :id)" do
      dnp_entry = %DnpEntry{id: 789}
      assert Paths.dnp_entry_path(dnp_entry) == ~p"/dnp/#{dnp_entry}"
      assert Paths.dnp_entry_path(dnp_entry) == "/dnp/789"
    end
  end

  describe "admin_report_path/1" do
    test "matches ~p for a report and a raw integer id" do
      report = %Report{id: 321}
      assert Paths.admin_report_path(report) == ~p"/admin/reports/#{report}"
      assert Paths.admin_report_path(321) == "/admin/reports/321"
    end
  end

  describe "artist_link_path/1 and artist_link_path/2" do
    test "artist_link_path/2 matches ~p (User → :slug, ArtistLink → :id)" do
      user = %User{slug: interesting_user_slug()}
      artist_link = %ArtistLink{id: 5}

      assert Paths.artist_link_path(user, artist_link) ==
               ~p"/profiles/#{user}/artist_links/#{artist_link}"
    end

    test "artist_link_path/1 uses the link's loaded :user association" do
      user = %User{slug: interesting_user_slug()}
      artist_link = %ArtistLink{id: 5, user: user}

      assert Paths.artist_link_path(artist_link) ==
               ~p"/profiles/#{user}/artist_links/#{artist_link}"

      assert Paths.artist_link_path(artist_link) == Paths.artist_link_path(user, artist_link)
    end
  end

  describe "ip_profile_path/1" do
    test "matches ~p for a plain IPv4 (dots are URI-unreserved)" do
      assert Paths.ip_profile_path("203.0.113.1") == ~p"/ip_profiles/#{"203.0.113.1"}"
      assert Paths.ip_profile_path("203.0.113.1") == "/ip_profiles/203.0.113.1"
    end

    test "percent-encodes the colons in an IPv6 address like ~p does" do
      ip = "2001:db8::1"
      assert Paths.ip_profile_path(ip) == ~p"/ip_profiles/#{ip}"
      assert Paths.ip_profile_path(ip) == "/ip_profiles/2001%3Adb8%3A%3A1"
    end
  end

  describe "fingerprint_profile_path/1" do
    test "matches ~p" do
      fingerprint = "c1234567890"

      assert Paths.fingerprint_profile_path(fingerprint) ==
               ~p"/fingerprint_profiles/#{fingerprint}"

      assert Paths.fingerprint_profile_path(fingerprint) == "/fingerprint_profiles/c1234567890"
    end
  end
end
