defmodule Philomena.SourceChangesFixtures do
  @moduledoc """
  Test helpers for `m:Philomena.SourceChanges.SourceChange` rows.

  Source changes are normally produced as a side effect of
  `Philomena.Images.update_sources/3`; the IP / fingerprint source-change pages
  filter them by attribution, so tests need rows with a chosen `ip` /
  `fingerprint`. The schema changeset casts nothing, so - like the `UserIp` /
  `UserFingerprint` fixtures - this inserts directly. `source_changes.ip`,
  `.fingerprint`, and `.value` are all `NOT NULL`, so both attribution fields
  always get a value.
  """

  import Philomena.UserIpsFixtures, only: [inet: 1]

  alias Philomena.Repo
  alias Philomena.SourceChanges.SourceChange

  @doc """
  Inserts a `SourceChange` row attributed to the given `ip` / `fingerprint`
  against `image`.

  Options (all with defaults): `:ip` (string, `"203.0.113.1"`),
  `:fingerprint` (`"c0ffee"`), `:source_url`, `:added`, `:user_id`.
  """
  def source_change_fixture(image, attrs \\ %{}) do
    now = DateTime.utc_now(:second)

    attrs =
      Enum.into(attrs, %{
        ip: "203.0.113.1",
        fingerprint: "c0ffee",
        source_url: "https://example.com/artwork",
        added: true,
        user_id: nil
      })

    Repo.insert!(%SourceChange{
      image_id: image.id,
      user_id: attrs.user_id,
      ip: inet(attrs.ip),
      fingerprint: attrs.fingerprint,
      source_url: attrs.source_url,
      added: attrs.added,
      created_at: now,
      updated_at: now
    })
  end
end
