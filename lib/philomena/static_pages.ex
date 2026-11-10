defmodule Philomena.StaticPages do
  @moduledoc """
  Public page presentation, staff-authored revisions, and generated site
  statistics content.

  The generated statistics page deliberately bypasses revision history because
  it is replaced by a periodic system service rather than a human editor.
  """

  import Ecto.Query, warn: false

  import Philomena.Authorization,
    only: [authorize: 3, verify_not_banned: 1, verify_write_access: 1]

  alias Philomena.Loader
  alias Philomena.Multi
  alias Philomena.Repo

  alias Philomena.Attribution.Actor
  alias Philomena.StaticPages.StaticPage
  alias Philomena.StaticPages.Version

  defp list_static_pages do
    Repo.all(StaticPage)
  end

  defp load_static_page(actor, action, slug) when is_binary(slug) do
    StaticPage
    |> where(slug: ^slug)
    |> Loader.one_and_authorize(actor, action)
  end

  defp load_static_page(_actor, _action, _slug), do: {:error, :not_found}

  defp create_static_page(user, attrs) do
    static_page = StaticPage.changeset(%StaticPage{}, attrs)

    Multi.new()
    |> Multi.insert(:static_page, static_page)
    |> Multi.insert(:version, fn %{static_page: static_page} ->
      %Version{static_page_id: static_page.id, user_id: user.id}
      |> Version.changeset(attrs)
    end)
    |> Multi.transact()
  end

  defp update_static_page(%StaticPage{} = static_page, user, attrs) do
    version =
      %Version{static_page_id: static_page.id, user_id: user.id}
      |> Version.changeset(attrs)

    static_page =
      static_page
      |> StaticPage.changeset(attrs)

    Multi.new()
    |> Multi.update(:static_page, static_page)
    |> Multi.insert(:version, version)
    |> Multi.transact()
  end

  defp change_static_page(%StaticPage{} = static_page) do
    StaticPage.changeset(static_page, %{})
  end

  @doc """
  Returns the static pages listing on behalf of `actor`.

  The listing is staff-only. Returns `{:error, :unauthorized}` when the viewer
  may not manage static pages, otherwise `{:ok, static_pages}`.

  ## Examples

      iex> list_pages(admin_actor)
      {:ok, [%StaticPage{}]}

  """
  @spec list_pages(Actor.t()) :: {:ok, [StaticPage.t()]} | {:error, :unauthorized}
  def list_pages(%Actor{} = actor) do
    with :ok <- authorize(actor, :index, StaticPage) do
      {:ok, list_static_pages()}
    end
  end

  @doc """
  Loads the static page named by `slug`, on behalf of `actor`.

  Missing pages are always not-found, while an existing forbidden page is
  unauthorized. Individual pages are public.

  ## Examples

      iex> show_page(actor, "about")
      {:ok, %StaticPage{}}

      iex> show_page(actor, "missing")
      {:error, :not_found}

  """
  @spec show_page(Actor.t(), String.t()) ::
          {:ok, StaticPage.t()} | {:error, :not_found | :unauthorized}
  def show_page(%Actor{} = actor, slug) do
    load_static_page(actor, :show, slug)
  end

  @doc """
  Loads the revision history for the static page named by `slug`, on behalf of
  `actor`.

  The page is loaded and authorized before its history query runs. On success,
  versions are newest first (ties broken by id) with their editors preloaded.

  ## Examples

      iex> list_page_history(actor, "about")
      {:ok, {%StaticPage{}, [%Version{}]}}

  """
  @spec list_page_history(Actor.t(), String.t()) ::
          {:ok, {StaticPage.t(), [Version.t()]}} | {:error, :not_found | :unauthorized}
  def list_page_history(%Actor{} = actor, slug) do
    with {:ok, static_page} <- load_static_page(actor, :show, slug) do
      versions =
        Version
        |> where(static_page_id: ^static_page.id)
        |> preload(:user)
        |> order_by(desc: :created_at, desc: :id)
        |> Repo.all()

      {:ok, {static_page, versions}}
    end
  end

  @doc """
  Prepares a new static page, on behalf of `actor`.

  The form enforces the same ban and `:new` authorization checks as creation,
  which additionally requires a fingerprint.

  ## Examples

      iex> new_page(admin_actor)
      {:ok, %Ecto.Changeset{}}

      iex> new_page(banned_actor)
      {:error, :ban}

  """
  @spec new_page(Actor.t()) ::
          {:ok, Ecto.Changeset.t()} | {:error, :ban | :unauthorized}
  def new_page(%Actor{} = actor) do
    with :ok <- verify_not_banned(actor),
         :ok <- authorize(actor, :new, StaticPage) do
      {:ok, change_static_page(%StaticPage{})}
    end
  end

  @doc """
  Creates a static page (with its initial version), on behalf of `actor`.

  The page and its initial revision commit atomically. Validation failures
  return the page changeset; successful calls return the created page.

  ## Examples

      iex> create_page(admin_actor, %{title: "About", slug: "about", body: "..."})
      {:ok, %StaticPage{}}

      iex> create_page(admin_actor, %{title: ""})
      {:error, %Ecto.Changeset{}}

  """
  @spec create_page(Actor.t(), map()) ::
          {:ok, StaticPage.t()}
          | {:error, Ecto.Changeset.t() | :ban | :unauthorized}
  def create_page(%Actor{} = actor, attrs) do
    with :ok <- verify_write_access(actor),
         :ok <- authorize(actor, :create, StaticPage) do
      actor.user
      |> create_static_page(attrs)
      |> case do
        {:ok, %{static_page: %StaticPage{} = static_page}} ->
          {:ok, static_page}

        {:error, :static_page, %Ecto.Changeset{} = changeset, _changes} ->
          {:error, changeset}
      end
    end
  end

  @doc """
  Loads the static page named by `slug` for edit, on behalf of `actor`.

  The form enforces the same ban and `:edit` authorization checks as
  update. Missing pages are always not-found.

  ## Examples

      iex> edit_page(admin_actor, "about")
      {:ok, {%StaticPage{}, %Ecto.Changeset{}}}

  """
  @spec edit_page(Actor.t(), String.t()) ::
          {:ok, {StaticPage.t(), Ecto.Changeset.t()}}
          | {:error, :ban | :not_found | :unauthorized}
  def edit_page(%Actor{} = actor, slug) do
    with :ok <- verify_not_banned(actor),
         {:ok, static_page} <- load_static_page(actor, :edit, slug) do
      {:ok, {static_page, change_static_page(static_page)}}
    end
  end

  @doc """
  Updates the static page named by `slug` (with a new version), on behalf of
  `actor`.

  The page update and revision insert commit atomically. Missing pages are
  always not-found; validation failures return the page changeset.

  ## Examples

      iex> update_page(admin_actor, "about", %{body: "Updated"})
      {:ok, %StaticPage{}}

  """
  @spec update_page(Actor.t(), String.t(), map()) ::
          {:ok, StaticPage.t()}
          | {:error, :ban | :not_found | :unauthorized | Ecto.Changeset.t()}
  def update_page(%Actor{} = actor, slug, attrs) do
    with :ok <- verify_write_access(actor),
         {:ok, static_page} <- load_static_page(actor, :update, slug) do
      static_page
      |> update_static_page(actor.user, attrs)
      |> case do
        {:ok, %{static_page: %StaticPage{} = static_page}} ->
          {:ok, static_page}

        {:error, :static_page, %Ecto.Changeset{} = changeset, _changes} ->
          {:error, changeset}
      end
    end
  end

  @doc """
  Creates or replaces the generated statistics page body.

  This service is used by the site statistics renderer. As there is no
  relevance to auditing its changes, it does not create any edit history.

  ## Examples

      iex> upsert_statistics_page("There are 42 images.")
      {1, nil}

  """
  @spec upsert_statistics_page(String.t()) :: {non_neg_integer(), nil | [term()]}
  def upsert_statistics_page(body) when is_binary(body) do
    now = DateTime.utc_now(:second)

    Repo.insert_all(
      StaticPage,
      [
        %{
          title: "Statistics",
          slug: "stats",
          body: body,
          created_at: now,
          updated_at: now
        }
      ],
      on_conflict: {:replace, [:body, :updated_at]},
      conflict_target: :slug
    )
  end
end
