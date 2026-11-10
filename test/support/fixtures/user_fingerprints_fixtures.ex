defmodule Philomena.UserFingerprintsFixtures do
  @moduledoc """
  Test helpers for `m:Philomena.UserFingerprints.UserFingerprint` rows.

  `UserFingerprint` rows are only ever written by `UserAttributionPlug`
  internals (the schema changeset casts nothing), so fixtures insert directly.
  """

  alias Philomena.Repo
  alias Philomena.UserFingerprints.UserFingerprint

  def unique_fingerprint, do: "c#{System.unique_integer([:positive])}"

  @doc """
  Inserts a `UserFingerprint` row associating `user` with `fingerprint`
  (default a fresh unique value).
  """
  def user_fingerprint_fixture(user, fingerprint \\ nil) do
    Repo.insert!(%UserFingerprint{
      user_id: user.id,
      fingerprint: fingerprint || unique_fingerprint(),
      uses: 1
    })
  end
end
