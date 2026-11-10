defmodule Philomena.Bans do
  @moduledoc """
  Ban enforcement and actor-scoped administration for user, subnet, and
  fingerprint bans.

  Handles automatic creation of subnet bans for an input user ban.

  This prevents trivial ban evasion with the creation of a new account from the same address.
  The user must work around or wait out the subnet ban first.
  """

  import Ecto.Query, warn: false

  import Philomena.Authorization,
    only: [authorize: 3, verify_not_banned: 1, verify_write_access: 1]

  alias Philomena.Repo
  alias Philomena.Loader

  alias Philomena.Attribution.Actor
  alias Philomena.Authorization
  alias Philomena.Bans.Finder
  alias Philomena.Bans.Fingerprint
  alias Philomena.Bans.FingerprintQueryBuilder
  alias Philomena.Bans.FingerprintQueryForm
  alias Philomena.Bans.Subnet
  alias Philomena.Bans.SubnetQueryBuilder
  alias Philomena.Bans.SubnetQueryForm
  alias Philomena.Bans.User
  alias Philomena.Bans.UserQueryBuilder
  alias Philomena.Bans.UserQueryForm
  alias Philomena.ModerationLogs
  alias Philomena.Multi
  alias Philomena.UserIps
  alias Philomena.Users

  # For every ban type: authorize on schema module first, then on instance.
  defp load_ban(actor, schema, id, action, preloads \\ []) do
    with {:ok, ban} <- Loader.fetch(schema, id, preloads),
         :ok <- authorize(actor, action, schema),
         :ok <- authorize(actor, action, ban) do
      {:ok, ban}
    end
  end

  @doc """
  Returns the fingerprint bans matching `fingerprint`, newest first.
  """
  @spec fingerprint_bans_for(String.t()) :: [Fingerprint.t()]
  def fingerprint_bans_for(fingerprint) do
    Fingerprint
    |> where(fingerprint: ^fingerprint)
    |> order_by(desc: :created_at)
    |> Repo.all()
  end

  @doc """
  Returns paginated fingerprint bans for the admin listing, on behalf of
  `actor`.

  Filters by the `"bq"` full-text search or the exact `"fingerprint"` branch
  when either is present in params. Results are ordered newest first.

  ## Examples

      iex> list_fingerprint_bans(admin, params, pagination)
      {:ok, %Scrivener.Page{}}

      iex> list_fingerprint_bans(user, params, pagination)
      {:error, :unauthorized}

  """
  @spec list_fingerprint_bans(Actor.t(), map(), Repo.pagination_params()) ::
          {:ok, Scrivener.Page.t(Fingerprint.t()), Ecto.Changeset.t()}
          | {:error, Ecto.Changeset.t()}
          | {:error, :unauthorized}
  def list_fingerprint_bans(%Actor{} = actor, params, pagination) do
    with :ok <- authorize(actor, :index, Fingerprint),
         {:ok, query, form} <- FingerprintQueryBuilder.build_query(params) do
      fingerprint_bans =
        query
        |> preload(:banning_user)
        |> Repo.paginate(pagination)

      {:ok, fingerprint_bans, FingerprintQueryForm.changeset(form)}
    end
  end

  @doc """
  Builds a changeset for a new fingerprint ban on behalf of `actor`, prefilling
  the fingerprint from the `fingerprint` argument (which may be `nil`).

  ## Examples

      iex> new_fingerprint_ban(admin, fingerprint)
      {:ok, %Ecto.Changeset{}}

      iex> new_fingerprint_ban(user, fingerprint)
      {:error, :unauthorized}

  """
  @spec new_fingerprint_ban(Actor.t(), String.t() | nil) ::
          {:ok, Ecto.Changeset.t()} | Authorization.write_error()
  def new_fingerprint_ban(%Actor{} = actor, fingerprint) do
    with :ok <- verify_not_banned(actor),
         :ok <- authorize(actor, :new, Fingerprint) do
      {:ok, Fingerprint.changeset(%Fingerprint{fingerprint: fingerprint})}
    end
  end

  @doc """
  Creates a fingerprint ban on behalf of `actor`.

  On success a moderation log attributing the creation to `actor` is written.

  ## Examples

      iex> create_fingerprint_ban(admin, ban_params)
      {:ok, %Fingerprint{}}

      iex> create_fingerprint_ban(admin, invalid_params)
      {:error, %Ecto.Changeset{}}

      iex> create_fingerprint_ban(user, ban_params)
      {:error, :unauthorized}

  """
  @spec create_fingerprint_ban(Actor.t(), map()) ::
          {:ok, Fingerprint.t()}
          | Authorization.write_error()
          | {:error, Ecto.Changeset.t()}
  def create_fingerprint_ban(%Actor{user: creator} = actor, attrs) do
    with :ok <- verify_write_access(actor),
         :ok <- authorize(actor, :create, Fingerprint) do
      fingerprint_changeset =
        %Fingerprint{banning_user_id: creator.id}
        |> Fingerprint.changeset(attrs)

      Multi.new()
      |> Multi.insert(:fingerprint, fingerprint_changeset)
      |> ModerationLogs.put_log(
        :moderation_log,
        actor,
        fn %{fingerprint: fingerprint} ->
          {
            "Admin.FingerprintBan:create",
            "/admin/fingerprint_bans",
            "Created a fingerprint ban #{fingerprint.generated_ban_id}"
          }
        end
      )
      |> Multi.transact()
      |> case do
        {:ok, %{fingerprint: %Fingerprint{} = fingerprint}} ->
          {:ok, fingerprint}

        {:error, :fingerprint, %Ecto.Changeset{} = changeset, _changes} ->
          {:error, changeset}
      end
    end
  end

  @doc """
  Loads the fingerprint ban named by `id` for editing, on behalf of `actor`,
  pairing it with a changeset for editing it.

  ## Examples

      iex> edit_fingerprint_ban(admin, fingerprint_ban_id)
      {:ok, {%Fingerprint{}, %Ecto.Changeset{}}}

      iex> edit_fingerprint_ban(admin, invalid_id)
      {:error, :not_found}

      iex> edit_fingerprint_ban(user, fingerprint_ban_id)
      {:error, :unauthorized}

  """
  @spec edit_fingerprint_ban(Actor.t(), Loader.integer_id()) ::
          {:ok, {Fingerprint.t(), Ecto.Changeset.t()}}
          | {:error, Authorization.write_error_reason() | :not_found}
  def edit_fingerprint_ban(%Actor{} = actor, id) do
    with :ok <- verify_not_banned(actor),
         {:ok, fingerprint_ban} <- load_ban(actor, Fingerprint, id, :edit) do
      {:ok, {fingerprint_ban, Fingerprint.changeset(fingerprint_ban)}}
    end
  end

  @doc """
  Updates the fingerprint ban named by `id`, on behalf of `actor`.

  On success a moderation log attributing the update to `actor` is written.

  ## Examples

      iex> update_fingerprint_ban(admin, fingerprint_ban_id, fingerprint_ban_params)
      {:ok, %Fingerprint{}}

      iex> update_fingerprint_ban(admin, fingerprint_ban_id, invalid_params)
      {:error, %Ecto.Changeset{}}

      iex> update_fingerprint_ban(admin, invalid_id, fingerprint_ban_params)
      {:error, :not_found}

      iex> update_fingerprint_ban(user, fingerprint_ban_id, fingerprint_ban_params)
      {:error, :unauthorized}

  """
  @spec update_fingerprint_ban(Actor.t(), Loader.integer_id(), map()) ::
          {:ok, Fingerprint.t()}
          | {:error, Authorization.write_error_reason() | :not_found | Ecto.Changeset.t()}
  def update_fingerprint_ban(%Actor{} = actor, id, attrs) do
    with :ok <- verify_write_access(actor),
         {:ok, fingerprint_ban} <- load_ban(actor, Fingerprint, id, :update) do
      fingerprint_changeset = Fingerprint.changeset(fingerprint_ban, attrs)

      Multi.new()
      |> Multi.update(:fingerprint, fingerprint_changeset)
      |> ModerationLogs.put_log(
        :moderation_log,
        actor,
        fn %{fingerprint: fingerprint} ->
          {
            "Admin.FingerprintBan:update",
            "/admin/fingerprint_bans",
            "Updated a fingerprint ban #{fingerprint.generated_ban_id}"
          }
        end
      )
      |> Multi.transact()
      |> case do
        {:ok, %{fingerprint: %Fingerprint{} = fingerprint}} ->
          {:ok, fingerprint}

        {:error, :fingerprint, %Ecto.Changeset{} = changeset, _changes} ->
          {:error, changeset}
      end
    end
  end

  @doc """
  Deletes the fingerprint ban named by `id`, on behalf of `actor`.

  On success a moderation log attributing the removal to `actor` is written.

  ## Examples

      iex> delete_fingerprint_ban(admin, fingerprint_ban_id)
      {:ok, %Fingerprint{}}

      iex> delete_fingerprint_ban(admin, invalid_id)
      {:error, :not_found}

      iex> delete_fingerprint_ban(user, fingerprint_ban_id)
      {:error, :unauthorized}

  """
  @spec delete_fingerprint_ban(Actor.t(), Loader.integer_id()) ::
          {:ok, Fingerprint.t()}
          | {:error, Authorization.write_error_reason() | :not_found}
  def delete_fingerprint_ban(%Actor{} = actor, id) do
    with :ok <- verify_write_access(actor),
         {:ok, fingerprint_ban} <- load_ban(actor, Fingerprint, id, :delete) do
      Multi.new()
      |> Multi.delete(:fingerprint, fingerprint_ban)
      |> ModerationLogs.put_log(
        :moderation_log,
        actor,
        fn %{fingerprint: fingerprint} ->
          {
            "Admin.FingerprintBan:delete",
            "/admin/fingerprint_bans",
            "Deleted a fingerprint ban #{fingerprint.generated_ban_id}"
          }
        end
      )
      |> Multi.transact()
      |> case do
        {:ok, %{fingerprint: %Fingerprint{} = fingerprint}} ->
          {:ok, fingerprint}

        {:error, :fingerprint, %Ecto.Changeset{} = changeset, _changes} ->
          {:error, changeset}
      end
    end
  end

  @doc """
  Returns the subnet bans whose specification contains `ip`, newest first.
  """
  @spec subnet_bans_for_ip(Postgrex.INET.t()) :: [Subnet.t()]
  def subnet_bans_for_ip(ip) do
    Subnet
    |> where([s], fragment("? >>= ?", s.specification, ^ip))
    |> order_by(desc: :created_at)
    |> Repo.all()
  end

  @doc """
  Returns paginated subnet bans for the admin listing, on behalf of
  `actor`.

  Filters by the `"bq"` full-text search or the `"ip"` branch
  when either is present in params. Results are ordered newest first.

  ## Examples

      iex> list_subnet_bans(admin, params, pagination)
      {:ok, %Scrivener.Page{}}

      iex> list_subnet_bans(admin, %{"ip" => "512.512.512.512"}, pagination)
      {:error, {:invalid_ip, "512.512.512.512}}

      iex> list_subnet_bans(user, params, pagination)
      {:error, :unauthorized}

  """
  @spec list_subnet_bans(Actor.t(), map(), Repo.pagination_params()) ::
          {:ok, Scrivener.Page.t(Subnet.t()), Ecto.Changeset.t()}
          | {:error, Ecto.Changeset.t()}
          | {:error, :unauthorized}
  def list_subnet_bans(%Actor{} = actor, params, pagination) do
    with :ok <- authorize(actor, :index, Subnet),
         {:ok, query, form} <- SubnetQueryBuilder.build_query(params) do
      subnet_bans =
        query
        |> preload(:banning_user)
        |> Repo.paginate(pagination)

      {:ok, subnet_bans, SubnetQueryForm.changeset(form)}
    end
  end

  @doc """
  Prepares a new subnet ban on behalf of `actor`, prefilling the specification
  from the `specification` argument (which may be `nil`).

  ## Examples

      iex> new_subnet_ban(admin, ip_or_cidr)
      {:ok, %Ecto.Changeset{}}

      iex> new_subnet_ban(admin, "512.512.512.512")
      {:error, %Ecto.Changeset{}}

      iex> new_subnet_ban(user, ip_or_cidr)
      {:error, :unauthorized}

  """
  @spec new_subnet_ban(Actor.t(), String.t() | nil) ::
          {:ok, Ecto.Changeset.t()}
          | {:error, Authorization.write_error_reason()}
  def new_subnet_ban(%Actor{} = actor, specification) do
    with :ok <- verify_not_banned(actor),
         :ok <- authorize(actor, :new, Subnet) do
      {:ok, Subnet.changeset(%Subnet{}, %{specification: specification})}
    end
  end

  @doc """
  Creates a subnet ban on behalf of `actor`.

  On success a moderation log attributing the creation to `actor` is written.

  ## Examples

      iex> create_subnet_ban(admin, ban_params)
      {:ok, %Subnet{}}

      iex> create_subnet_ban(admin, invalid_params)
      {:error, %Ecto.Changeset{}}

      iex> create_subnet_ban(user, ban_params)
      {:error, :unauthorized}

  """
  @spec create_subnet_ban(Actor.t(), map()) ::
          {:ok, Subnet.t()}
          | Authorization.write_error()
          | {:error, Ecto.Changeset.t()}
  def create_subnet_ban(%Actor{user: creator} = actor, attrs) do
    with :ok <- verify_write_access(actor),
         :ok <- authorize(actor, :create, Subnet) do
      subnet_changeset =
        %Subnet{banning_user_id: creator.id}
        |> Subnet.changeset(attrs)

      Multi.new()
      |> Multi.insert(:subnet, subnet_changeset)
      |> ModerationLogs.put_log(
        :moderation_log,
        actor,
        fn %{subnet: subnet} ->
          {
            "Admin.SubnetBan:create",
            "/admin/subnet_bans",
            "Created a subnet ban #{subnet.generated_ban_id}"
          }
        end
      )
      |> Multi.transact()
      |> case do
        {:ok, %{subnet: %Subnet{} = subnet}} ->
          {:ok, subnet}

        {:error, :subnet, %Ecto.Changeset{} = changeset, _changes} ->
          {:error, changeset}
      end
    end
  end

  @doc """
  Loads the subnet ban named by `id` for editing, on behalf of `actor`,
  pairing it with a changeset for editing it.

  ## Examples

      iex> edit_subnet_ban(admin, subnet_ban_id)
      {:ok, {%Subnet{}, %Ecto.Changeset{}}}

      iex> edit_subnet_ban(admin, invalid_id)
      {:error, :not_found}

      iex> edit_subnet_ban(user, subnet_ban_id)
      {:error, :unauthorized}

  """
  @spec edit_subnet_ban(Actor.t(), Loader.integer_id()) ::
          {:ok, {Subnet.t(), Ecto.Changeset.t()}}
          | {:error, Authorization.write_error_reason() | :not_found}
  def edit_subnet_ban(%Actor{} = actor, id) do
    with :ok <- verify_not_banned(actor),
         {:ok, subnet_ban} <- load_ban(actor, Subnet, id, :edit) do
      {:ok, {subnet_ban, Subnet.changeset(subnet_ban)}}
    end
  end

  @doc """
  Updates the subnet ban named by `id`, on behalf of `actor`.

  On success a moderation log attributing the update to `actor` is written.

  ## Examples

      iex> update_subnet_ban(admin, subnet_ban_id, subnet_ban_params)
      {:ok, %Subnet{}}

      iex> update_subnet_ban(admin, subnet_ban_id, invalid_params)
      {:error, %Ecto.Changeset{}}

      iex> update_subnet_ban(admin, invalid_id, subnet_ban_params)
      {:error, :not_found}

      iex> update_subnet_ban(user, subnet_ban_id, subnet_ban_params)
      {:error, :unauthorized}

  """
  @spec update_subnet_ban(Actor.t(), Loader.integer_id(), map()) ::
          {:ok, Subnet.t()}
          | {:error, Authorization.write_error_reason() | :not_found | Ecto.Changeset.t()}
  def update_subnet_ban(%Actor{} = actor, id, attrs) do
    with :ok <- verify_write_access(actor),
         {:ok, subnet_ban} <- load_ban(actor, Subnet, id, :update) do
      subnet_changeset = Subnet.changeset(subnet_ban, attrs)

      Multi.new()
      |> Multi.update(:subnet, subnet_changeset)
      |> ModerationLogs.put_log(
        :moderation_log,
        actor,
        fn %{subnet: subnet} ->
          {
            "Admin.SubnetBan:update",
            "/admin/subnet_bans",
            "Updated a subnet ban #{subnet.generated_ban_id}"
          }
        end
      )
      |> Multi.transact()
      |> case do
        {:ok, %{subnet: %Subnet{} = subnet}} ->
          {:ok, subnet}

        {:error, :subnet, %Ecto.Changeset{} = changeset, _changes} ->
          {:error, changeset}
      end
    end
  end

  @doc """
  Deletes the subnet ban named by `id`, on behalf of `actor`.

  On success a moderation log attributing the removal to `actor` is written.

  ## Examples

      iex> delete_subnet_ban(admin, subnet_ban_id)
      {:ok, %Subnet{}}

      iex> delete_subnet_ban(admin, invalid_id)
      {:error, :not_found}

      iex> delete_subnet_ban(user, subnet_ban_id)
      {:error, :unauthorized}

  """
  @spec delete_subnet_ban(Actor.t(), Loader.integer_id()) ::
          {:ok, Subnet.t()}
          | {:error, Authorization.write_error_reason() | :not_found}
  def delete_subnet_ban(%Actor{} = actor, id) do
    with :ok <- verify_write_access(actor),
         {:ok, subnet_ban} <- load_ban(actor, Subnet, id, :delete) do
      Multi.new()
      |> Multi.delete(:subnet, subnet_ban)
      |> ModerationLogs.put_log(
        :moderation_log,
        actor,
        fn %{subnet: subnet} ->
          {
            "Admin.SubnetBan:delete",
            "/admin/subnet_bans",
            "Deleted a subnet ban #{subnet.generated_ban_id}"
          }
        end
      )
      |> Multi.transact()
      |> case do
        {:ok, %{subnet: %Subnet{} = subnet}} ->
          {:ok, subnet}

        {:error, :subnet, %Ecto.Changeset{} = changeset, _changes} ->
          {:error, changeset}
      end
    end
  end

  defp create_user_multi(%Users.User{} = creator, %Users.User{} = target, attrs) do
    user_changeset =
      %User{banning_user_id: creator.id, user_id: target.id}
      |> User.changeset(attrs)

    Multi.new()
    |> Multi.insert(:user, user_changeset)
    |> Multi.run(:subnet, fn repo, _changes ->
      # Create a subnet ban for the given user's last known IP address as part
      # of the user-ban creation transaction. No ban is created if none is known.
      case UserIps.latest_ip_for_user(target.id) do
        nil ->
          {:ok, nil}

        ip ->
          %Subnet{banning_user_id: creator.id}
          |> Subnet.paired_ban_changeset(%{specification: ip})
          |> Subnet.changeset(attrs)
          |> repo.insert()
      end
    end)
    |> Multi.on_commit(fn _changes ->
      Users.reindex_user(%Users.User{id: target.id})
    end)
  end

  @doc """
  Returns paginated user bans for the admin listing, on behalf of
  `actor`.

  Filters by the `"bq"` full-text search or the exact `"user_id"` branch
  when either is present in params. Results are ordered newest first.

  ## Examples

      iex> list_user_bans(admin, params, pagination)
      {:ok, %Scrivener.Page{}}

      iex> list_user_bans(user, params, pagination)
      {:error, :unauthorized}

  """
  @spec list_user_bans(Actor.t(), map(), Repo.pagination_params()) ::
          {:ok, Scrivener.Page.t(User.t()), Ecto.Changeset.t()}
          | {:error, Ecto.Changeset.t()}
          | {:error, :unauthorized}
  def list_user_bans(%Actor{} = actor, params, pagination) do
    with :ok <- authorize(actor, :index, User),
         {:ok, query, form} <- UserQueryBuilder.build_query(params) do
      user_bans =
        query
        |> preload([:user, :banning_user])
        |> Repo.paginate(pagination)

      {:ok, user_bans, UserQueryForm.changeset(form)}
    end
  end

  @doc """
  Builds a changeset for a new user ban on behalf of `actor`, prefilling
  the user from the `user_id` argument and optionally applying `attrs` for form
  redisplay. The target is loaded safely inside the authorized context boundary.

  ## Examples

      iex> new_user_ban(admin, user_id)
      {:ok, {%Users.User{}, %Ecto.Changeset{}}}

      iex> new_user_ban(admin, invalid_user_id)
      {:error, :not_found}

      iex> new_user_ban(user, user_id)
      {:error, :unauthorized}

  """
  @spec new_user_ban(Actor.t(), Loader.integer_id(), map()) ::
          {:ok, {Users.User.t(), Ecto.Changeset.t()}}
          | {:error, Authorization.write_error_reason() | :not_found}
  def new_user_ban(%Actor{} = actor, user_id, attrs \\ %{}) do
    with :ok <- verify_not_banned(actor),
         {:ok, target} <- Loader.fetch(Users.User, user_id),
         :ok <- authorize(actor, :new, User) do
      {:ok, {target, %User{user_id: target.id} |> User.changeset(attrs)}}
    end
  end

  @doc """
  Creates a user ban on behalf of `actor`.

  On success a moderation log attributing the creation to `actor` is written.

  ## Examples

      iex> create_user_ban(admin, user_id, ban_params)
      {:ok, %User{}}

      iex> create_user_ban(admin, user_id, invalid_params)
      {:error, %Ecto.Changeset{}}

      iex> create_user_ban(user, user_id, ban_params)
      {:error, :unauthorized}

  """
  @spec create_user_ban(Actor.t(), Loader.integer_id(), map()) ::
          {:ok, User.t()}
          | {:error, Authorization.write_error_reason() | :not_found | Ecto.Changeset.t()}
  def create_user_ban(%Actor{user: creator} = actor, user_id, attrs) do
    with :ok <- verify_write_access(actor),
         {:ok, target} <- Loader.fetch(Users.User, user_id),
         :ok <- authorize(actor, :create, User) do
      creator
      |> create_user_multi(target, attrs)
      |> ModerationLogs.put_log(
        :moderation_log,
        actor,
        fn %{user: user} ->
          {
            "Admin.UserBan:create",
            "/admin/user_bans",
            "Created a user ban #{user.generated_ban_id}"
          }
        end
      )
      |> Multi.transact()
      |> case do
        {:ok, %{user: %User{} = user}} ->
          {:ok, user}

        {:error, :user, %Ecto.Changeset{} = changeset, _changes} ->
          {:error, changeset}
      end
    end
  end

  @doc """
  Loads the user ban named by `id` for editing, on behalf of `actor`,
  pairing it with a changeset for editing it.

  ## Examples

      iex> edit_user_ban(admin, user_ban_id)
      {:ok, {%User{}, %Ecto.Changeset{}}}

      iex> edit_user_ban(admin, invalid_id)
      {:error, :not_found}

      iex> edit_user_ban(user, user_ban_id)
      {:error, :unauthorized}

  """
  @spec edit_user_ban(Actor.t(), Loader.integer_id()) ::
          {:ok, {User.t(), Ecto.Changeset.t()}}
          | {:error, Authorization.write_error_reason() | :not_found}
  def edit_user_ban(%Actor{} = actor, id) do
    with :ok <- verify_not_banned(actor),
         {:ok, user_ban} <- load_ban(actor, User, id, :edit, [:user]) do
      {:ok, {user_ban, User.changeset(user_ban)}}
    end
  end

  @doc """
  Updates the user ban named by `id`, on behalf of `actor`.

  On success a moderation log attributing the update to `actor` is written.

  ## Examples

      iex> update_user_ban(admin, user_ban_id, user_ban_params)
      {:ok, %User{}}

      iex> update_user_ban(admin, user_ban_id, invalid_params)
      {:error, %Ecto.Changeset{}}

      iex> update_user_ban(admin, invalid_id, user_ban_params)
      {:error, :not_found}

      iex> update_user_ban(user, user_ban_id, user_ban_params)
      {:error, :unauthorized}

  """
  @spec update_user_ban(Actor.t(), Loader.integer_id(), map()) ::
          {:ok, User.t()}
          | {:error, Authorization.write_error_reason() | :not_found | Ecto.Changeset.t()}
  def update_user_ban(%Actor{} = actor, id, attrs) do
    with :ok <- verify_write_access(actor),
         {:ok, user_ban} <- load_ban(actor, User, id, :update, [:user]) do
      user_changeset = User.changeset(user_ban, attrs)

      Multi.new()
      |> Multi.update(:user, user_changeset)
      |> ModerationLogs.put_log(
        :moderation_log,
        actor,
        fn %{user: user} ->
          {
            "Admin.UserBan:update",
            "/admin/user_bans",
            "Updated a user ban #{user.generated_ban_id}"
          }
        end
      )
      |> Multi.transact()
      |> case do
        {:ok, %{user: %User{} = user}} ->
          {:ok, user}

        {:error, :user, %Ecto.Changeset{} = changeset, _changes} ->
          {:error, changeset}
      end
    end
  end

  @doc """
  Deletes the user ban named by `id`, on behalf of `actor`.

  On success a moderation log attributing the removal to `actor` is written.

  ## Examples

      iex> delete_user_ban(admin, user_ban_id)
      {:ok, %User{}}

      iex> delete_user_ban(admin, invalid_id)
      {:error, :not_found}

      iex> delete_user_ban(user, user_ban_id)
      {:error, :unauthorized}

  """
  @spec delete_user_ban(Actor.t(), Loader.integer_id()) ::
          {:ok, User.t()}
          | {:error, Authorization.write_error_reason() | :not_found}
  def delete_user_ban(%Actor{} = actor, id) do
    with :ok <- verify_write_access(actor),
         {:ok, user_ban} <- load_ban(actor, User, id, :delete) do
      Multi.new()
      |> Multi.delete(:user, user_ban)
      |> ModerationLogs.put_log(
        :moderation_log,
        actor,
        fn %{user: user} ->
          {
            "Admin.UserBan:delete",
            "/admin/user_bans",
            "Deleted a user ban #{user.generated_ban_id}"
          }
        end
      )
      |> Multi.transact()
      |> case do
        {:ok, %{user: %User{} = user}} ->
          {:ok, user}

        {:error, :user, %Ecto.Changeset{} = changeset, _changes} ->
          {:error, changeset}
      end
    end
  end

  @doc """
  Returns the effective ban, if any, matching the request identity.

  This request-time lookup is deliberately unauthenticated. Signed-in requests
  consider only their user ban. Anonymous requests prefer a matching subnet ban
  over a fingerprint ban when both apply. Within one ban kind, the newest ban
  wins.
  """
  @spec find(
          Users.User.t() | nil,
          Postgrex.INET.t() | :inet.ip_address() | nil,
          String.t() | nil
        ) :: map() | nil
  def find(user, ip, fingerprint) do
    Finder.find(user, ip, fingerprint)
  end
end
