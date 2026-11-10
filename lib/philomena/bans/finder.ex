defmodule Philomena.Bans.Finder do
  @moduledoc """
  Finds the effective ban associated with a set of request attributes.
  """

  import Ecto.Query, warn: false
  alias Philomena.Repo

  alias Philomena.Bans.Fingerprint
  alias Philomena.Bans.Subnet
  alias Philomena.Bans.User

  @fingerprint "Fingerprint"
  @subnet "Subnet"
  @user "User"

  # User bans have the highest priority, followed by subnet bans, then
  # by fingerprint bans.
  #
  # Note that signed-in users will never receive subnet or fingerprint
  # bans; they can only receive user bans. So the priority enumerated
  # here for user bans is effectively a placeholder.
  @user_ban_priority 0
  @subnet_ban_priority 1
  @fingerprint_ban_priority 2

  @doc """
  Returns the first ban, if any, that matches the specified request attributes.
  """
  @spec find(
          Philomena.Users.User.t() | nil,
          Postgrex.INET.t() | :inet.ip_address() | nil,
          String.t() | nil
        ) ::
          map() | nil
  def find(user, ip, fingerprint) do
    queries =
      generate_valid_queries([
        {ip, &subnet_query/2},
        {fingerprint, &fingerprint_query/2},
        {user, &user_query/2}
      ])

    bans =
      case queries do
        [] ->
          []

        queries ->
          queries
          |> Enum.reduce(&union_all(&2, ^&1))
          |> Repo.all()
      end

    # Don't return a fingerprint or subnet ban if the user is currently signed in.
    if is_nil(user) do
      effective_ban(bans)
    else
      user_ban(bans)
    end
  end

  defp query_base(schema, name, priority, now) do
    from b in schema,
      where: b.enabled and b.valid_until > ^now,
      select: %{
        reason: b.reason,
        valid_until: b.valid_until,
        generated_ban_id: b.generated_ban_id,
        type: type(^name, :string),
        priority: type(^priority, :integer),
        sort_at: b.created_at
      }
  end

  defp fingerprint_query(fingerprint, now) do
    Fingerprint
    |> query_base(@fingerprint, @fingerprint_ban_priority, now)
    |> where([f], f.fingerprint == ^fingerprint)
  end

  defp subnet_query(ip, now) do
    {:ok, inet} = EctoNetwork.INET.cast(ip)

    Subnet
    |> query_base(@subnet, @subnet_ban_priority, now)
    |> where(fragment("specification >>= ?", ^inet))
  end

  defp user_query(user, now) do
    User
    |> query_base(@user, @user_ban_priority, now)
    |> where([u], u.user_id == ^user.id)
  end

  defp generate_valid_queries(sources) do
    now = DateTime.utc_now()

    Enum.flat_map(sources, fn
      {nil, _cb} -> []
      {source, cb} -> [cb.(source, now)]
    end)
  end

  defp user_ban(bans) do
    bans
    |> Enum.filter(&(&1.type == @user))
    |> effective_ban()
  end

  defp effective_ban([]), do: nil

  defp effective_ban(bans) do
    bans
    |> Enum.min_by(fn ban -> {ban.priority, -DateTime.to_unix(ban.sort_at)} end)
    |> Map.drop([:priority, :sort_at])
  end
end
