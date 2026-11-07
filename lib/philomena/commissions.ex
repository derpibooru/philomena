defmodule Philomena.Commissions do
  @moduledoc """
  Commission directory, profile listings, and listing item management.
  """

  import Ecto.Query, warn: false

  import Philomena.Authorization,
    only: [authorize: 3, verify_not_banned: 1, verify_write_access: 1]

  alias Philomena.Multi
  alias Philomena.Attribution.Actor
  alias Philomena.Commissions.Commission
  alias Philomena.Commissions.Directory
  alias Philomena.Commissions.Item
  alias Philomena.Commissions.QueryBuilder
  alias Philomena.Commissions.QueryForm
  alias Philomena.IntegerId
  alias Philomena.Loader
  alias Philomena.Repo
  alias Philomena.Reports
  alias Philomena.Users
  alias Philomena.Users.User

  @profile_preloads [:commission, :verified_links]
  @commission_preloads [
    sheet_image: [:sources, tags: :aliases],
    user: [awards: :badge],
    items: [example_image: [:sources, tags: :aliases]]
  ]

  defp load_profile(actor, slug, _action) do
    Users.load_profile(actor, slug, @profile_preloads)
  end

  defp load_profile_commission(%Actor{} = actor, %User{id: user_id}, action) do
    Commission
    |> where(user_id: ^user_id)
    |> preload(^@commission_preloads)
    |> Loader.one_and_authorize(actor, action)
  end

  defp load_commission_item(%Commission{} = commission, id) do
    Item
    |> where(commission_id: ^commission.id)
    |> preload(commission: :user)
    |> Loader.fetch(id)
  end

  defp new_commission(%Actor{} = actor, %User{} = user, action) do
    commission =
      user
      |> Ecto.build_assoc(:commission)
      |> Map.put(:user, user)

    with :ok <- authorize(actor, action, commission) do
      cond do
        not is_nil(user.commission) ->
          {:error, :unauthorized}

        Enum.empty?(user.verified_links) ->
          {:error, :no_verified_links}

        true ->
          {:ok, commission}
      end
    end
  end

  defp new_item(%Commission{} = commission) do
    commission
    |> Ecto.build_assoc(:items)
    |> Map.put(:commission, commission)
  end

  @doc """
  Loads the public commission directory for `actor`.

  The `:index` commission ability is checked before searching. Results include
  only open listings with items whose active owner has recent activity.
  Invalid search parameters return an empty page and the rejected search
  changeset. If present, the viewing user is returned with commission preloaded.

  ## Examples

      iex> list_commissions(actor, params, page: 1, page_size: 25)
      {:ok, %Directory{}}

  """
  @spec list_commissions(Actor.t(), map(), Repo.pagination_params()) ::
          {:ok, Directory.t()} | {:error, :unauthorized}
  def list_commissions(%Actor{user: user} = actor, params, pagination) do
    with :ok <- authorize(actor, :index, Commission) do
      {commissions, changeset} =
        params
        |> QueryBuilder.search_commissions()
        |> case do
          {:ok, query, query_form} ->
            {Repo.paginate(query, pagination), QueryForm.changeset(query_form)}

          {:error, changeset} ->
            {nil, changeset}
        end

      {:ok,
       %Directory{
         commissions: commissions,
         changeset: changeset,
         current_user: Repo.preload(user, @profile_preloads)
       }}
    end
  end

  @doc """
  Loads the profile named by `slug` and its visible commission listing.

  The profile is loaded following `Users.load_profile/3`; one without a
  listing is not found.
  Items are returned by ascending base price with ID as a deterministic tie
  breaker.

  ## Examples

      iex> show_commission(actor, "artist")
      {:ok, %Commission{}}

  """
  @spec show_commission(Actor.t(), String.t()) ::
          {:ok, Commission.t()} | {:error, :unauthorized | :not_found}
  def show_commission(%Actor{} = actor, slug) do
    with {:ok, user} <- load_profile(actor, slug, :show) do
      load_profile_commission(actor, user, :show)
    end
  end

  @doc """
  Loads a visible commission listing as a report target.

  This shares the active profile and `:show` gates used by the listing page.

  ## Examples

      iex> load_report_target(actor, "artist")
      {:ok, %Commission{}}

  """
  @spec load_report_target(Actor.t(), String.t()) ::
          {:ok, Commission.t()} | {:error, :unauthorized | :not_found}
  def load_report_target(%Actor{} = actor, slug) do
    show_commission(actor, slug)
  end

  @doc """
  Builds a new commission form for the active profile named by `slug`.

  A ban is checked before loading; a missing fingerprint is not. The owner,
  moderators, and admins may manage a commission on the profile's behalf. The
  profile must have a verified artist link and no existing commission.

  ## Examples

      iex> new_commission(actor, "artist")
      {:ok, %Ecto.Changeset{}}

  """
  @spec new_commission(Actor.t(), String.t()) ::
          {:ok, Ecto.Changeset.t()}
          | {:error, :ban | :unauthorized | :not_found | :no_verified_links}
  def new_commission(%Actor{} = actor, slug) do
    with :ok <- verify_not_banned(actor),
         {:ok, user} <- load_profile(actor, slug, :show),
         {:ok, commission} <- new_commission(actor, user, :new) do
      {:ok, Commission.changeset(commission)}
    end
  end

  @doc """
  Creates the sole commission listing for the active profile named by `slug`.

  Authorization and verified link rules match `new_commission/2`. The database
  uniquely enforces one commission per profile. Validation failures return a
  `m:Ecto.Changeset` retaining the loaded profile and attempted changes.

  ## Examples

      iex> create_commission(actor, "artist", attrs)
      {:ok, %Commission{}}

      iex> create_commission(actor, "artist", invalid_attrs)
      {:error, %Ecto.Changeset{}}

  """
  @spec create_commission(Actor.t(), String.t(), map()) ::
          {:ok, Commission.t()}
          | {:error, Ecto.Changeset.t()}
          | {:error, :ban | :unauthorized | :not_found | :no_verified_links}
  def create_commission(%Actor{} = actor, slug, attrs) do
    with :ok <- verify_write_access(actor),
         {:ok, user} <- load_profile(actor, slug, :show),
         {:ok, commission} <- new_commission(actor, user, :create),
         {:ok, commission} <-
           commission
           |> Commission.changeset(attrs)
           |> Repo.insert() do
      {:ok, Repo.preload(commission, @commission_preloads)}
    end
  end

  @doc """
  Loads the existing commission form for the active profile named by `slug`.

  Ban, owner/staff authorization, and verified link requirements match the
  update operation, which additionally requires a fingerprint.

  ## Examples

      iex> edit_commission(actor, "artist")
      {:ok, %Ecto.Changeset{}}

  """
  @spec edit_commission(Actor.t(), String.t()) ::
          {:ok, Ecto.Changeset.t()}
          | {:error, :ban | :unauthorized | :not_found}
  def edit_commission(%Actor{} = actor, slug) do
    with :ok <- verify_not_banned(actor),
         {:ok, user} <- load_profile(actor, slug, :show),
         {:ok, commission} <- load_profile_commission(actor, user, :edit) do
      {:ok, Commission.changeset(commission)}
    end
  end

  @doc """
  Updates the existing commission for the active profile named by `slug`.

  Validation failures return a `m:Ecto.Changeset`. Successful updates preserve
  item ordering and count.

  ## Examples

      iex> update_commission(actor, "artist", attrs)
      {:ok, %Commission{}}

  """
  @spec update_commission(Actor.t(), String.t(), map()) ::
          {:ok, Commission.t()}
          | {:error, Ecto.Changeset.t()}
          | {:error, :ban | :unauthorized | :not_found}
  def update_commission(%Actor{} = actor, slug, attrs) do
    with :ok <- verify_write_access(actor),
         {:ok, user} <- load_profile(actor, slug, :show),
         {:ok, commission} <- load_profile_commission(actor, user, :update) do
      commission
      |> Commission.changeset(attrs)
      |> Repo.update()
    end
  end

  @doc """
  Deletes the commission for the active profile named by `slug`.

  The commission, its items, and its report-target foreign keys are delete atomically.
  Open reports are closed by the acting user and reindexed only after commit.

  ## Examples

      iex> delete_commission(actor, "artist")
      {:ok, %Commission{}}

  """
  @spec delete_commission(Actor.t(), String.t()) ::
          {:ok, Commission.t()}
          | {:error, :ban | :unauthorized | :not_found}
  def delete_commission(%Actor{user: closing_user} = actor, slug) do
    with :ok <- verify_write_access(actor),
         {:ok, user} <- load_profile(actor, slug, :show),
         {:ok, commission} <- load_profile_commission(actor, user, :delete) do
      Multi.new()
      |> Reports.put_close_reports(:reports, closing_user, commission_id: commission.id)
      |> Multi.delete(:commission, commission)
      |> Multi.transact()
      |> case do
        {:ok, %{commission: %Commission{} = commission}} ->
          {:ok, commission}

        {:error, :commission, %Ecto.Changeset{} = changeset, _changes} ->
          {:error, changeset}
      end
    end
  end

  @doc """
  Builds a new item changeset for the commission belonging to the active profile
  named by `slug`.

  Creating commission items requires permission to edit the commission. A ban is
  checked before the profile and commission are loaded; a missing fingerprint
  is not.

  ## Examples

      iex> new_item(actor, "artist")
      {:ok, %Ecto.Changeset{}}

  """
  @spec new_item(Actor.t(), String.t()) ::
          {:ok, Ecto.Changeset.t()} | {:error, :ban | :unauthorized | :not_found}
  def new_item(%Actor{} = actor, slug) do
    with :ok <- verify_not_banned(actor),
         {:ok, user} <- load_profile(actor, slug, :show),
         {:ok, commission} <- load_profile_commission(actor, user, :new_item) do
      {:ok,
       commission
       |> new_item()
       |> Item.changeset()}
    end
  end

  @doc """
  Creates an item under the commission belonging to the active profile named by
  `slug` and increments the listing's item count.

  ## Examples

      iex> create_item(actor, "artist", attrs)
      {:ok, %Item{}}

      iex> create_item(actor, "artist", invalid_attrs)
      {:error, %Ecto.Changeset{}}

  """
  @spec create_item(Actor.t(), String.t(), map()) ::
          {:ok, Item.t()}
          | {:error, Ecto.Changeset.t()}
          | {:error, :ban | :unauthorized | :not_found}
  def create_item(%Actor{} = actor, slug, attrs) do
    with :ok <- verify_write_access(actor),
         {:ok, user} <- load_profile(actor, slug, :show),
         {:ok, commission} <- load_profile_commission(actor, user, :create_item) do
      changeset =
        commission
        |> new_item()
        |> Item.changeset(attrs)

      counter_query =
        Commission
        |> where(id: ^commission.id)
        |> update(inc: [commission_items_count: 1])

      Multi.new()
      |> Multi.insert(:item, changeset)
      |> Multi.update_all(:commission, counter_query, [])
      |> Multi.transact()
      |> case do
        {:ok, %{item: %Item{} = item}} ->
          {:ok, item}

        {:error, :item, %Ecto.Changeset{} = changeset, _changes} ->
          {:error, changeset}
      end
    end
  end

  @doc """
  Loads the item named by `id` for editing under the commission belonging to
  the active profile named by `slug`.

  The item lookup is constrained by the commission before authorization.
  Malformed, absent, and wrong-commission IDs are all not found.

  ## Examples

      iex> edit_item(actor, "artist", "12")
      {:ok, %Ecto.Changeset{}}

      iex> edit_item(actor, "artist", "bad")
      {:error, :not_found}

  """
  @spec edit_item(Actor.t(), String.t(), IntegerId.integer_id()) ::
          {:ok, Ecto.Changeset.t()} | {:error, :ban | :unauthorized | :not_found}
  def edit_item(%Actor{} = actor, slug, id) do
    with :ok <- verify_not_banned(actor),
         {:ok, user} <- load_profile(actor, slug, :show),
         {:ok, commission} <- load_profile_commission(actor, user, :edit_item),
         {:ok, item} <- load_commission_item(commission, id) do
      {:ok, Item.changeset(item)}
    end
  end

  @doc """
  Updates the item named by `id` under the commission belonging to the active
  profile named by `slug`.

  The item lookup is constrained by the commission before authorization.
  Malformed, absent, and wrong-commission IDs are all not found. Validation
  failures return an `m:Ecto.Changeset`.

  ## Examples

      iex> update_item(actor, "artist", "12", attrs)
      {:ok, %Item{}}

  """
  @spec update_item(Actor.t(), String.t(), IntegerId.integer_id(), map()) ::
          {:ok, Item.t()}
          | {:error, Ecto.Changeset.t()}
          | {:error, :ban | :unauthorized | :not_found}
  def update_item(%Actor{} = actor, slug, id, attrs) do
    with :ok <- verify_write_access(actor),
         {:ok, user} <- load_profile(actor, slug, :show),
         {:ok, commission} <- load_profile_commission(actor, user, :update_item),
         {:ok, item} <- load_commission_item(commission, id) do
      item
      |> Item.changeset(attrs)
      |> Repo.update()
    end
  end

  @doc """
  Deletes the item named by `id` under the commission belonging to the active
  profile named by `slug` and decrements the listing's item count.

  Malformed, absent, and wrong-commission IDs are all not found.

  ## Examples

      iex> delete_item(actor, "artist", "12")
      {:ok, %Item{}}

  """
  @spec delete_item(Actor.t(), String.t(), IntegerId.integer_id()) ::
          {:ok, Item.t()} | {:error, :ban | :unauthorized | :not_found}
  def delete_item(%Actor{} = actor, slug, id) do
    with :ok <- verify_write_access(actor),
         {:ok, user} <- load_profile(actor, slug, :show),
         {:ok, commission} <- load_profile_commission(actor, user, :delete_item),
         {:ok, item} <- load_commission_item(commission, id) do
      counter_query =
        Commission
        |> where(id: ^item.commission_id)
        |> update(inc: [commission_items_count: -1])

      Multi.new()
      |> Multi.delete(:item, item)
      |> Multi.update_all(:commission, counter_query, [])
      |> Multi.transact()
      |> case do
        {:ok, %{item: %Item{} = item}} ->
          {:ok, item}

        {:error, :item, %Ecto.Changeset{} = changeset, _changes} ->
          {:error, changeset}
      end
    end
  end
end
