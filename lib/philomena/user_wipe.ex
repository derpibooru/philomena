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
  import Ecto.Query

  def perform(user_id) do
    user = Users.get_user!(user_id)

    random_hex = :crypto.strong_rand_bytes(16) |> Base.encode16(case: :lower)

    for schema <- [Comment, Image, Post, Report, SourceChange, TagChange] do
      schema
      |> where(user_id: ^user.id)
      |> in_batches(&Repo.update_all(&1, set: [ip: @wipe_ip, fingerprint: @wipe_fp]))
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

  defp in_batches(queryable, mapper) do
    queryable = order_by(queryable, asc: :id)

    ids =
      queryable
      |> select([q], q.id)
      |> limit(1000)
      |> Repo.all()

    in_batches(queryable, mapper, 1000, ids)
  end

  defp in_batches(_queryable, _mapper, _batch_size, []), do: nil

  defp in_batches(queryable, mapper, batch_size, ids) do
    queryable
    |> where([q], q.id in ^ids)
    |> exclude(:order_by)
    |> mapper.()

    ids =
      queryable
      |> where([q], q.id > ^Enum.max(ids))
      |> select([q], q.id)
      |> limit(^batch_size)
      |> Repo.all()

    in_batches(queryable, mapper, batch_size, ids)
  end
end
