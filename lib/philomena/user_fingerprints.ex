defmodule Philomena.UserFingerprints do
  @moduledoc """
  Fingerprint profiles, user history, and browser fingerprint validation.
  """

  import Ecto.Query, warn: false
  import Philomena.Authorization, only: [authorize: 3]

  alias Philomena.Repo

  alias Philomena.Attribution.Actor
  alias Philomena.Bans
  alias Philomena.UserFingerprints.UserFingerprint
  alias Philomena.UserFingerprints.FingerprintProfile
  alias Philomena.UserFingerprints.Server
  alias Philomena.Users.User

  defp cast_fingerprint(fingerprint) when is_binary(fingerprint) do
    fingerprint =
      fingerprint
      |> String.trim()
      |> String.downcase()

    if valid_format?(fingerprint) do
      {:ok, fingerprint}
    else
      {:error, :not_found}
    end
  end

  defp cast_fingerprint(_fingerprint), do: {:error, :not_found}

  defp user_fingerprints_for(fingerprint) do
    UserFingerprint
    |> where(fingerprint: ^fingerprint)
    |> order_by(desc: :updated_at)
    |> preload(:user)
    |> Repo.all()
  end

  defp history_query(%User{id: user_id}) do
    UserFingerprint
    |> where(user_id: ^user_id)
    |> order_by(desc: :updated_at, desc: :id)
  end

  defp cross_references(fingerprints) do
    UserFingerprint
    |> where([u], u.fingerprint in ^fingerprints)
    |> preload(:user)
    |> order_by(desc: :updated_at)
    |> Repo.all()
    |> Enum.group_by(& &1.fingerprint)
  end

  @doc """
  Asynchronously records usage of a fingerprint by `user`.

  Invalid fingerprints return `:error`.

  ## Example

      iex> record_usage(user, "d63c4581f8cf58d", ~U[2024-01-01 00:00:00Z])
      :ok

  """
  @spec record_usage(User.t(), term(), DateTime.t()) :: :ok | :error
  def record_usage(%User{id: user_id}, fingerprint, updated_at) do
    Server.record_usage(user_id, fingerprint, updated_at)
  end

  @doc """
  Assembles the fingerprint profile page for `actor` from the raw
  `fingerprint` string.

  The input is trimmed, lowercased, and validated before the `:identity_metadata`
  permission is checked. Malformed fingerprints are therefore always not found.
  Valid fingerprints with no matching history return an empty profile.

  Returns `{:ok, %FingerprintProfile{}}` carrying the users seen with the
  fingerprint and the fingerprint bans matching it.
  """
  @spec show_fingerprint_profile(Actor.t(), String.t()) ::
          {:ok, FingerprintProfile.t()} | {:error, :unauthorized | :not_found}
  def show_fingerprint_profile(%Actor{} = actor, fingerprint) do
    with {:ok, fingerprint} <- cast_fingerprint(fingerprint),
         :ok <- authorize(actor, :show, :identity_metadata) do
      {:ok,
       %FingerprintProfile{
         fingerprint: fingerprint,
         user_fingerprints: user_fingerprints_for(fingerprint),
         fingerprint_bans: Bans.fingerprint_bans_for(fingerprint)
       }}
    end
  end

  @doc """
  Loads a paginated fingerprint history for `user` and cross-references the
  fingerprints on the current page for `actor`.

  `actor` must be authorized to show `:identity_metadata`.

  ## Examples

      iex> load_user_history(moderator, user, page: 1, page_size: 25)
      {:ok, {%Scrivener.Page{}, %{"fingerprint" => [%UserFingerprint{}]}}}

  """
  @spec load_user_history(Actor.t(), User.t(), Repo.pagination_params()) ::
          {:ok, {Scrivener.Page.t(UserFingerprint.t()), map()}} | {:error, :unauthorized}
  def load_user_history(%Actor{} = actor, %User{} = user, pagination) do
    with :ok <- authorize(actor, :show, :identity_metadata) do
      user_fingerprints =
        user
        |> history_query()
        |> Repo.paginate(pagination)

      fingerprints =
        user_fingerprints.entries
        |> Enum.map(& &1.fingerprint)
        |> Enum.uniq()

      {:ok, {user_fingerprints, cross_references(fingerprints)}}
    end
  end

  @doc """
  Returns the latest fingerprint history row for `user`, if any, after authorizing
  the `:identity_metadata` permission.

  ## Examples

      iex> latest_for_user(moderator, user)
      {:ok, %UserFingerprint{}}

  """
  @spec latest_for_user(Actor.t(), User.t()) ::
          {:ok, UserFingerprint.t() | nil} | {:error, :unauthorized}
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
  Deletes all stored fingerprint history for a user.
  """
  @spec delete_for_user!(integer()) :: :ok
  def delete_for_user!(user_id) do
    Repo.delete_all(where(UserFingerprint, user_id: ^user_id))
    :ok
  end

  @doc """
  Persists the batching server's coalesced fingerprint usage.
  """
  @spec persist_usage_batch(%{{pos_integer(), String.t()} => DateTime.t()}) :: :ok
  def persist_usage_batch(user_fingerprints) when is_map(user_fingerprints) do
    if map_size(user_fingerprints) > 0 do
      update_query =
        update(UserFingerprint,
          inc: [uses: 1],
          set: [updated_at: fragment("EXCLUDED.updated_at")]
        )

      usage_rows =
        Enum.map(user_fingerprints, fn {{user_id, fingerprint}, updated_at} ->
          %UserFingerprint{user_id: user_id}
          |> UserFingerprint.changeset(%{fingerprint: fingerprint})
          |> Ecto.Changeset.apply_changes()
          |> Map.take(UserFingerprint.insert_fields())
          |> Map.merge(%{created_at: updated_at, updated_at: updated_at})
        end)

      Repo.insert_all(
        UserFingerprint,
        usage_rows,
        on_conflict: update_query,
        conflict_target: [:user_id, :fingerprint]
      )
    end

    :ok
  end

  @doc """
  Determine whether the fingerprint corresponds to a valid format.

  Valid formats start with `c` or `d` (for the version). The `c` format is a legacy format
  corresponding to an integer-valued hash from the frontend. The `d` format is the current
  format corresponding to a hex-valued hash from the frontend. By design, it is not
  possible to infer anything else about these values from the server.

  See assets/js/fp.ts for additional information on the generation of the `d` format.

  ## Examples

      iex> valid_format?("b2502085657")
      false

      iex> valid_format?("c637334158")
      true

      iex> valid_format?("d63c4581f8cf58d")
      true

      iex> valid_format?("5162549b16e8448")
      false

  """
  @spec valid_format?(term()) :: boolean()
  def valid_format?(fingerprint)

  def valid_format?(<<"c", rest::binary>>) when byte_size(rest) <= 12 do
    match?({_result, ""}, Integer.parse(rest))
  end

  def valid_format?(<<"d", rest::binary>>) when byte_size(rest) == 14 do
    match?({:ok, _result}, Base.decode16(rest, case: :lower))
  end

  def valid_format?(_fingerprint), do: false
end
