defmodule Philomena.UserIps do
  @moduledoc """
  IP profiles, user history, and latest IP lookup for automatic ban enforcement.
  """

  import Ecto.Query, warn: false
  import Philomena.Authorization, only: [authorize: 3]

  alias Philomena.Repo

  alias Philomena.Attribution.Actor
  alias Philomena.Bans
  alias Philomena.UserIps.UserIp
  alias Philomena.UserIps.IpProfile
  alias Philomena.UserIps.Server
  alias Philomena.Users.User

  defp cast_ip(ip) do
    case EctoNetwork.INET.cast(ip) do
      {:ok, ip} ->
        {:ok, ip}

      _error ->
        {:error, :not_found}
    end
  end

  defp user_ips_for(ip) do
    UserIp
    |> where(fragment("? >>= ip", ^ip))
    |> order_by(desc: :updated_at)
    |> preload(:user)
    |> Repo.all()
  end

  defp history_query(%User{id: user_id}) do
    UserIp
    |> where(user_id: ^user_id)
    |> order_by(desc: :updated_at, desc: :id)
  end

  defp cross_references(ips) do
    UserIp
    |> where([u], u.ip in ^ips)
    |> preload(:user)
    |> order_by(desc: :updated_at)
    |> Repo.all()
    |> Enum.group_by(& &1.ip)
  end

  @doc """
  Asynchronously records usage of an IP address by `user`.

  Invalid IP addresses return `:error`.

  ## Example

      iex> record_usage(user, {127, 0, 0, 1}, ~U[2024-01-01 00:00:00Z])
      :ok

  """
  @spec record_usage(User.t(), term(), DateTime.t()) :: :ok | :error
  def record_usage(%User{id: user_id}, ip_address, updated_at) do
    Server.record_usage(user_id, ip_address, updated_at)
  end

  @doc """
  Assembles the IP profile page for `actor` from the raw address string `ip`.

  The address is parsed and canonicalized before the `:identity_metadata`
  permission is checked. A malformed address is therefore always not found; a
  valid address with no matching history returns an empty profile.

  Returns `{:ok, %IpProfile{}}` carrying the users seen on the address and the
  subnet bans covering it.
  """
  @spec show_ip_profile(Actor.t(), String.t()) ::
          {:ok, IpProfile.t()} | {:error, :unauthorized | :not_found}
  def show_ip_profile(%Actor{} = actor, ip) do
    with {:ok, ip} <- cast_ip(ip),
         :ok <- authorize(actor, :show, :identity_metadata) do
      {:ok,
       %IpProfile{
         ip: ip,
         user_ips: user_ips_for(ip),
         subnet_bans: Bans.subnet_bans_for_ip(ip)
       }}
    end
  end

  @doc """
  Loads a paginated IP history for `user` and cross-references the IPs on the
  current page for `actor`.

  `actor` must be authorized to show `:identity_metadata`.

  ## Examples

      iex> load_user_history(moderator, user, page: 1, page_size: 25)
      {:ok, {%Scrivener.Page{}, %{ip => [%UserIp{}]}}}

  """
  @spec load_user_history(Actor.t(), User.t(), Repo.pagination_params()) ::
          {:ok, {Scrivener.Page.t(UserIp.t()), map()}} | {:error, :unauthorized}
  def load_user_history(%Actor{} = actor, %User{} = user, pagination) do
    with :ok <- authorize(actor, :show, :identity_metadata) do
      user_ips =
        user
        |> history_query()
        |> Repo.paginate(pagination)

      ips =
        user_ips.entries
        |> Enum.map(& &1.ip)
        |> Enum.uniq()

      {:ok, {user_ips, cross_references(ips)}}
    end
  end

  @doc """
  Returns the latest IP history row for `user`, if any, after authorizing the
  `:identity_metadata` permission.

  ## Examples

      iex> latest_for_user(moderator, user)
      {:ok, %UserIp{}}

  """
  @spec latest_for_user(Actor.t(), User.t()) ::
          {:ok, UserIp.t() | nil} | {:error, :unauthorized}
  def latest_for_user(%Actor{} = actor, %User{} = user) do
    with :ok <- authorize(actor, :show, :identity_metadata) do
      {:ok,
       user
       |> history_query()
       |> limit(1)
       |> Repo.one()}
    end
  end

  @doc """
  Returns the latest recorded IP for `user_id`, if any.

  This function is designed for automatic subnet creation when a user is
  banned. Request-facing code must use `load_ip_profile/2`, which applies the
  `:identity_metadata` permission.
  """
  @spec latest_ip_for_user(pos_integer()) :: Postgrex.INET.t() | nil
  def latest_ip_for_user(user_id) do
    UserIp
    |> where(user_id: ^user_id)
    |> order_by(desc: :updated_at)
    |> limit(1)
    |> select([u], u.ip)
    |> Repo.one()
  end

  @doc """
  Deletes all stored IP history for a user.
  """
  @spec delete_for_user!(integer()) :: :ok
  def delete_for_user!(user_id) do
    Repo.delete_all(where(UserIp, user_id: ^user_id))
    :ok
  end

  @doc """
  Persists the batching server's coalesced IP usage.
  """
  @spec persist_usage_batch(%{{pos_integer(), Postgrex.INET.t()} => DateTime.t()}) :: :ok
  def persist_usage_batch(user_ips) when is_map(user_ips) do
    if map_size(user_ips) > 0 do
      update_query =
        update(UserIp, inc: [uses: 1], set: [updated_at: fragment("EXCLUDED.updated_at")])

      usage_rows =
        Enum.map(user_ips, fn {{user_id, ip_address}, updated_at} ->
          %UserIp{user_id: user_id}
          |> UserIp.changeset(%{ip: ip_address})
          |> Ecto.Changeset.apply_changes()
          |> Map.take(UserIp.insert_fields())
          |> Map.merge(%{created_at: updated_at, updated_at: updated_at})
        end)

      Repo.insert_all(
        UserIp,
        usage_rows,
        on_conflict: update_query,
        conflict_target: [:user_id, :ip]
      )
    end

    :ok
  end
end
