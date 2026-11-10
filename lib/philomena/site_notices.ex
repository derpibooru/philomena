defmodule Philomena.SiteNotices do
  @moduledoc """
  Public notice scheduling and authorized administrative management.

  Public readers can fetch notices in their active UTC window without an
  actor. Administrative functions are actor-first, enforce the global write
  prerequisite for form and mutation paths, and distinguish missing records
  from forbidden records.
  """

  import Ecto.Query, warn: false

  import Philomena.Authorization,
    only: [authorize: 3, verify_not_banned: 1, verify_write_access: 1]

  alias Philomena.Attribution.Actor
  alias Philomena.Authorization
  alias Philomena.Loader
  alias Philomena.Repo
  alias Philomena.SiteNotices.SiteNotice

  defp load_site_notice(actor, id, action) do
    Loader.fetch_and_authorize(SiteNotice, actor, action, id)
  end

  @doc """
  Returns currently active public notices, newest first.

  A notice is active only when it is live and the current UTC time is strictly
  between its start and finish times.

  ## Examples

      iex> active_site_notices()
      [%SiteNotice{}, ...]

  """
  @spec active_site_notices() :: [SiteNotice.t()]
  def active_site_notices do
    now = DateTime.utc_now()

    SiteNotice
    |> where(live: true)
    |> where([n], n.start_date < ^now and n.finish_date > ^now)
    |> order_by(desc: :start_date)
    |> Repo.all()
  end

  @doc """
  Returns the paginated site notices for the admin listing, on behalf of
  `actor`, newest start date first.

  Authorizes `:index` against the site-notice model. Returns
  `{:ok, site_notices}` or `{:error, :unauthorized}`.

  ## Examples

      iex> list_site_notices(actor, %{page_number: 1, page_size: 25})
      {:ok, %Scrivener.Page{}}

      iex> list_site_notices(regular_user_actor, %{page_number: 1, page_size: 25})
      {:error, :unauthorized}

  """
  @spec list_site_notices(Actor.t(), Repo.pagination_params()) ::
          {:ok, Scrivener.Page.t()} | {:error, :unauthorized}
  def list_site_notices(%Actor{} = actor, pagination) do
    with :ok <- authorize(actor, :index, SiteNotice) do
      site_notices =
        SiteNotice
        |> order_by(desc: :start_date)
        |> Repo.paginate(pagination)

      {:ok, site_notices}
    end
  end

  @doc """
  Builds the changeset for a new site notice, on behalf of `actor`.

  Rejects a banned actor, then authorizes `:new` against the site-notice model.

  ## Examples

      iex> new_site_notice(admin_actor)
      {:ok, %Ecto.Changeset{}}

      iex> new_site_notice(banned_admin_actor)
      {:error, :ban}

  """
  @spec new_site_notice(Actor.t()) ::
          {:ok, Ecto.Changeset.t()} | Authorization.write_error()
  def new_site_notice(%Actor{} = actor) do
    with :ok <- verify_not_banned(actor),
         :ok <- authorize(actor, :new, SiteNotice) do
      {:ok, SiteNotice.changeset(%SiteNotice{})}
    end
  end

  @doc """
  Creates a site notice on behalf of `actor`, whose user becomes its author.

  Verifies write access, authorizes `:create` against the site-notice model, and
  attributes the inserted notice to the actor's user.

  ## Examples

      iex> create_site_notice(admin, %{field: value})
      {:ok, %SiteNotice{}}

      iex> create_site_notice(admin, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  @spec create_site_notice(Actor.t(), map()) ::
          {:ok, SiteNotice.t()}
          | Authorization.write_error()
          | {:error, Ecto.Changeset.t()}
  def create_site_notice(%Actor{} = actor, attrs \\ %{}) do
    with :ok <- verify_write_access(actor),
         :ok <- authorize(actor, :create, SiteNotice) do
      %SiteNotice{user_id: actor.user.id}
      |> SiteNotice.changeset(attrs)
      |> Repo.insert()
    end
  end

  @doc """
  Loads the site notice named by the `id` for editing, on behalf of
  `actor`, pairing it with a change-tracking changeset.

  Rejects a banned actor, then loads the notice and authorizes `:edit` against
  the real record. Malformed and absent IDs are always not found.

  ## Examples

      iex> edit_site_notice(admin_actor, "12")
      {:ok, {%SiteNotice{}, %Ecto.Changeset{}}}

      iex> edit_site_notice(admin_actor, "missing")
      {:error, :not_found}

  """
  @spec edit_site_notice(Actor.t(), Loader.integer_id()) ::
          {:ok, {SiteNotice.t(), Ecto.Changeset.t()}}
          | {:error, Authorization.write_error_reason() | :not_found}
  def edit_site_notice(%Actor{} = actor, id) do
    with :ok <- verify_not_banned(actor),
         {:ok, site_notice} <- load_site_notice(actor, id, :edit) do
      {:ok, {site_notice, SiteNotice.changeset(site_notice)}}
    end
  end

  @doc """
  Updates the site notice named by the `id`, on behalf of `actor`.

  Verifies write access before loading the real record and authorizing
  `:update`. A validation failure returns its changeset.

  ## Examples

      iex> update_site_notice(admin_actor, "12", %{title: "Maintenance"})
      {:ok, %SiteNotice{}}

      iex> update_site_notice(admin_actor, "12", %{title: ""})
      {:error, %Ecto.Changeset{}}

  """
  @spec update_site_notice(Actor.t(), Loader.integer_id(), map()) ::
          {:ok, SiteNotice.t()}
          | {:error, Authorization.write_error_reason() | :not_found | Ecto.Changeset.t()}
  def update_site_notice(%Actor{} = actor, id, params) do
    with :ok <- verify_write_access(actor),
         {:ok, site_notice} <- load_site_notice(actor, id, :update) do
      site_notice
      |> SiteNotice.changeset(params)
      |> Repo.update()
    end
  end

  @doc """
  Deletes the site notice named by the `id`, on behalf of `actor`.

  Verifies write access before loading the real record and authorizing
  `:delete`.

  ## Examples

      iex> delete_site_notice(admin_actor, "12")
      {:ok, %SiteNotice{}}

      iex> delete_site_notice(admin_actor, "missing")
      {:error, :not_found}

  """
  @spec delete_site_notice(Actor.t(), Loader.integer_id()) ::
          {:ok, SiteNotice.t()}
          | {:error, Authorization.write_error_reason() | :not_found}
  def delete_site_notice(%Actor{} = actor, id) do
    with :ok <- verify_write_access(actor),
         {:ok, site_notice} <- load_site_notice(actor, id, :delete) do
      Repo.delete(site_notice)
    end
  end
end
