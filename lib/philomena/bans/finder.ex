defmodule Philomena.Bans.Finder do
  @moduledoc """
  Helper to find a bans associated with a set of request attributes.
  """

  import Ecto.Query, warn: false
  alias Philomena.Repo

  alias Philomena.Bans.Fingerprint
  alias Philomena.Bans.Subnet
  alias Philomena.Bans.User

  @fingerprint "Fingerprint"
  @subnet "Subnet"
  @user "User"

  @doc """
  Returns the first ban, if any, that matches the specified request attributes.
  """
  def find(user, ip, fingerprint) do
    bans =
      generate_valid_queries([
        {ip, &subnet_query/2},
        {fingerprint, &fingerprint_query/2},
        {user, &user_query/2}
      ])
      |> union_all_queries()
      |> Repo.all()

    # Don't return a fingerprint or subnet ban if the user is currently signed in.
    case is_nil(user) do
      true -> Enum.at(bans, 0)
      false -> user_ban(bans)
    end
  end

  defp query_base(schema, name, now) do
    from b in schema,
      where: b.enabled and b.valid_until > ^now,
      select: %{
        reason: b.reason,
        valid_until: b.valid_until,
        generated_ban_id: b.generated_ban_id,
        type: type(^name, :string)
      }
  end

  defp fingerprint_query(fingerprint, now) do
    Fingerprint
    |> query_base(@fingerprint, now)
    |> where([f], f.fingerprint == ^fingerprint)
  end

  defp subnet_query(ip, now) do
    {:ok, inet} = EctoNetwork.INET.cast(ip)

    Subnet
    |> query_base(@subnet, now)
    |> where(fragment("specification >>= ?", ^inet))
  end

  defp user_query(user, now) do
    User
    |> query_base(@user, now)
    |> where([u], u.user_id == ^user.id)
  end

  defp generate_valid_queries(sources) do
    now = DateTime.utc_now()

    Enum.flat_map(sources, fn
      {nil, _cb} -> []
      {source, cb} -> [cb.(source, now)]
    end)
  end

  defp union_all_queries([query | rest]) do
    Enum.reduce(rest, query, fn q, acc -> union_all(acc, ^q) end)
  end

  defp user_ban(bans) do
    bans
    |> Enum.filter(&(&1.type == @user))
    |> Enum.at(0)
  end
end
