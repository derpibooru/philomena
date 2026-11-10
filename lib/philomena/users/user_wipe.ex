defmodule Philomena.Users.UserWipe do
  @moduledoc """
  Performs the asynchronous personally identifying information cleanup owned by
  the Users context.

  The public entry point accepts only a trusted persisted user ID and is called
  by `Philomena.UserWipeWorker` after an authorized Users service enqueues it.
  """

  alias Philomena.Comments
  alias Philomena.Images
  alias Philomena.Posts
  alias Philomena.Reports
  alias Philomena.SourceChanges
  alias Philomena.TagChanges
  alias Philomena.UserIps
  alias Philomena.UserFingerprints
  alias Philomena.Users
  alias Philomena.Users.User

  @wipe_ip %Postgrex.INET{address: {127, 0, 1, 1}, netmask: 32}
  @wipe_fp "ffff"

  @doc """
  Replaces a user's stored IPs, fingerprints, and email with erased values.

  A missing ID is an invariant violation and raises. Attribution-bearing rows
  are updated in batches and the user search document is reindexed afterward.

  ## Examples

      iex> UserWipe.perform(user.id)
      %User{}
  """
  @spec perform(integer()) :: User.t()
  def perform(user_id) do
    user = Users.fetch_user_for_worker!(user_id)

    random_hex = :crypto.strong_rand_bytes(16) |> Base.encode16(case: :lower)

    Comments.wipe_user_attribution!(user.id, @wipe_ip, @wipe_fp)
    Images.wipe_user_attribution!(user.id, @wipe_ip, @wipe_fp)
    Posts.wipe_user_attribution!(user.id, @wipe_ip, @wipe_fp)
    Reports.wipe_user_attribution!(user.id, @wipe_ip, @wipe_fp)
    SourceChanges.wipe_user_attribution!(user.id, @wipe_ip, @wipe_fp)
    TagChanges.wipe_user_attribution!(user.id, @wipe_ip, @wipe_fp)
    UserIps.delete_for_user!(user.id)
    UserFingerprints.delete_for_user!(user.id)
    Users.replace_email_for_wipe!(user.id, "deactivated#{random_hex}@example.com")

    Users.reindex_user(user)
  end
end
