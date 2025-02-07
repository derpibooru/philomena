defmodule Philomena.UserWipe do
  @wipe_ip %Postgrex.INET{address: {127, 0, 1, 1}, netmask: 32}
  @wipe_fp "ffff"

  alias Philomena.Comments.Comment
  alias Philomena.Images.Image
  alias Philomena.Posts.Post
  alias Philomena.Reports.Report
  alias Philomena.SourceChanges.SourceChange
  alias Philomena.TagChanges.TagChange
  alias Philomena.UserIps.UserIp
  alias Philomena.UserFingerprints.UserFingerprint
  alias Philomena.Users
  alias Philomena.Users.User
  alias Philomena.Repo
  alias PhilomenaQuery.Batch
  import Ecto.Query

  def perform(user_id) do
    user = Users.get_user!(user_id)

    random_hex = :crypto.strong_rand_bytes(16) |> Base.encode16(case: :lower)

    for schema <- [Comment, Image, Post, Report, SourceChange, TagChange] do
      schema
      |> where(user_id: ^user.id)
      |> Batch.query_batches()
      |> Enum.each(&Repo.update_all(&1, set: [ip: @wipe_ip, fingerprint: @wipe_fp]))
    end

    UserIp
    |> where(user_id: ^user.id)
    |> Repo.delete_all()

    UserFingerprint
    |> where(user_id: ^user.id)
    |> Repo.delete_all()

    User
    |> where(id: ^user.id)
    |> Repo.update_all(set: [email: "deactivated#{random_hex}@example.com"])
  end
end
