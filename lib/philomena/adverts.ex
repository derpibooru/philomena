defmodule Philomena.Adverts do
  @moduledoc """
  Advert selection, click/impression tracking, and administration.
  """

  import Ecto.Query, warn: false

  import Philomena.Authorization,
    only: [authorize: 3, verify_not_banned: 1, verify_write_access: 1]

  alias Philomena.Adverts.{Advert, Restrictions, Server, Uploader}
  alias Philomena.Attribution.Actor
  alias Philomena.Authorization
  alias Philomena.Images.Image
  alias Philomena.Loader
  alias Philomena.ModerationLogs
  alias Philomena.Multi
  alias Philomena.Repo

  defp live_adverts_query(restrictions \\ nil) do
    now = DateTime.utc_now()

    query =
      Advert
      |> where(live: true)
      |> where([a], a.start_date < ^now and a.finish_date > ^now)

    if restrictions do
      where(query, [a], a.restrictions in ^restrictions)
    else
      query
    end
  end

  defp random_live_for_tags(tags) do
    tags
    |> Restrictions.tags()
    |> live_adverts_query()
    |> order_by(asc: fragment("random()"))
    |> limit(1)
    |> Repo.one()
  end

  defp load_advert(actor, action, id) do
    Loader.fetch_and_authorize(Advert, actor, action, id)
  end

  defp increment_counter({id, count}, field) do
    Advert
    |> where(id: ^id)
    |> Repo.update_all(inc: [{field, count}])
  end

  @doc """
  Gets an advert that is currently live.

  Returns the advert, or nil if nothing was live.

      iex> random_live()
      nil

      iex> random_live()
      %Advert{}

  """
  @spec random_live() :: Advert.t() | nil
  def random_live do
    random_live_for_tags([])
  end

  @doc """
  Gets an advert that is currently live, matching any tagging restrictions
  for the given image.

  Returns the advert, or nil if nothing was live.

  ## Examples

      iex> random_live(%Image{})
      nil

      iex> random_live(%Image{})
      %Advert{}

  """
  @spec random_live(Image.t()) :: Advert.t() | nil
  def random_live(image) do
    image
    |> Repo.preload(:tags)
    |> Map.get(:tags)
    |> Enum.map(& &1.name)
    |> random_live_for_tags()
  end

  @doc """
  Asynchronously records a new impression.

  ## Example

      iex> record_impression(%Advert{})
      :ok

  """
  @spec record_impression(Advert.t()) :: :ok
  def record_impression(%Advert{id: id}) do
    Server.record_impression(id)
  end

  @doc """
  Loads the currently live advert named by `id` and asynchronously records a
  click. Malformed, absent, disabled, not-yet-started, and expired adverts are
  not found.

  ## Example

      iex> record_click(advert.id)
      {:ok, %Advert{}}

  """
  @spec record_click(Loader.integer_id()) :: {:ok, Advert.t()} | {:error, :not_found}
  def record_click(id) do
    with {:ok, advert} <- Loader.fetch(live_adverts_query(), id),
         :ok <- Server.record_click(advert.id) do
      {:ok, advert}
    end
  end

  @doc """
  Returns paginated adverts for the admin listing, on behalf of `actor`,
  newest finish date first.

  ## Examples

      iex> list_adverts(admin, pagination)
      {:ok, %Scrivener.Page{}}

      iex> list_adverts(user, pagination)
      {:error, :unauthorized}

  """
  @spec list_adverts(Actor.t(), Repo.pagination_params()) ::
          {:ok, Scrivener.Page.t(Advert.t())} | {:error, :unauthorized}
  def list_adverts(%Actor{} = actor, pagination) do
    with :ok <- authorize(actor, :index, Advert) do
      adverts =
        Advert
        |> order_by(desc: :finish_date)
        |> Repo.paginate(pagination)

      {:ok, adverts}
    end
  end

  @doc """
  Builds the changeset for a new advert, on behalf of `actor`.

  Returns an `%Ecto.Changeset{}` for tracking advert changes.

  ## Examples

      iex> new_advert(admin)
      {:ok, %Ecto.Changeset{}}

      iex> new_advert(user)
      {:error, :unauthorized}

  """
  @spec new_advert(Actor.t()) :: {:ok, Ecto.Changeset.t()} | Authorization.write_error()
  def new_advert(%Actor{} = actor) do
    with :ok <- verify_not_banned(actor),
         :ok <- authorize(actor, :new, Advert) do
      {:ok, Advert.changeset(%Advert{})}
    end
  end

  @doc """
  Creates an advert with an image, on behalf of `actor`.

  On success a moderation log attributing the creation to `actor` is written.

  ## Examples

      iex> create_advert(admin, advert_params, upload)
      {:ok, %Advert{}}

      iex> create_advert(user, advert_params, upload)
      {:error, :unauthorized}

  """
  @spec create_advert(Actor.t(), map(), PhilomenaMedia.Upload.t() | nil) ::
          {:ok, Advert.t()} | Authorization.write_error() | {:error, Ecto.Changeset.t()}
  def create_advert(%Actor{} = actor, attrs, upload) do
    with :ok <- verify_write_access(actor),
         :ok <- authorize(actor, :create, Advert) do
      advert_changeset =
        %Advert{}
        |> Advert.changeset(attrs)
        |> Uploader.analyze_upload(upload)

      Multi.new()
      |> Multi.insert(:advert, advert_changeset)
      |> Uploader.put_persist_upload_and_unpersist_old(:advert)
      |> ModerationLogs.put_log(:moderation_log, actor, fn %{advert: advert} ->
        {"Admin.Advert:create", "/admin/adverts", "Created advert #{advert.id}"}
      end)
      |> Multi.transact()
      |> case do
        {:ok, %{advert: %Advert{} = advert}} ->
          {:ok, advert}

        {:error, :advert, %Ecto.Changeset{} = changeset, _changes} ->
          {:error, changeset}
      end
    end
  end

  @doc """
  Loads the advert named by the `id` for editing, on behalf of
  `actor`, pairing it with a change-tracking changeset.

  ## Examples

      iex> edit_advert(admin, advert_id)
      {:ok, {%Advert{}, %Ecto.Changeset{}}}

      iex> edit_advert(admin, invalid_id)
      {:error, :not_found}

      iex> edit_advert(user, advert_id)
      {:error, :unauthorized}

  """
  @spec edit_advert(Actor.t(), Loader.integer_id()) ::
          {:ok, {Advert.t(), Ecto.Changeset.t()}}
          | {:error, Authorization.write_error_reason() | :not_found}
  def edit_advert(%Actor{} = actor, id) do
    with :ok <- verify_not_banned(actor),
         {:ok, advert} <- load_advert(actor, :edit, id) do
      {:ok, {advert, Advert.changeset(advert)}}
    end
  end

  @doc """
  Updates the advert named by the `id` without touching its image,
  on behalf of `actor`.

  On success a moderation log attributing the update to `actor` is written.

  ## Examples

      iex> update_advert(admin, advert_id, advert_params)
      {:ok, %Advert{}}

      iex> update_advert(admin, advert_id, invalid_params)
      {:error, %Ecto.Changeset{}}

      iex> update_advert(admin, invalid_id, advert_params)
      {:error, :not_found}

      iex> update_advert(user, advert_id, advert_params)
      {:error, :unauthorized}

  """
  @spec update_advert(Actor.t(), Loader.integer_id(), map()) ::
          {:ok, Advert.t()}
          | {:error, Authorization.write_error_reason() | :not_found | Ecto.Changeset.t()}
  def update_advert(%Actor{} = actor, id, attrs) do
    with :ok <- verify_write_access(actor),
         {:ok, advert} <- load_advert(actor, :update, id) do
      advert_changeset = Advert.changeset(advert, attrs)

      Multi.new()
      |> Multi.update(:advert, advert_changeset)
      |> ModerationLogs.put_log(:moderation_log, actor, fn %{advert: advert} ->
        {"Admin.Advert:update", "/admin/adverts", "Updated advert #{advert.id}"}
      end)
      |> Multi.transact()
      |> case do
        {:ok, %{advert: %Advert{} = advert}} ->
          {:ok, advert}

        {:error, :advert, %Ecto.Changeset{} = changeset, _changes} ->
          {:error, changeset}
      end
    end
  end

  @doc """
  Deletes the advert named by the `id`, on behalf of `actor`.

  On success a moderation log attributing the deletion to `actor` is written.

  ## Examples

      iex> delete_advert(admin, advert_id)
      {:ok, %Advert{}}

      iex> delete_advert(admin, invalid_id)
      {:error, :not_found}

      iex> delete_advert(user, advert_id)
      {:error, :unauthorized}

  """
  @spec delete_advert(Actor.t(), Loader.integer_id()) ::
          {:ok, Advert.t()} | {:error, Authorization.write_error_reason() | :not_found}
  def delete_advert(%Actor{} = actor, id) do
    with :ok <- verify_write_access(actor),
         {:ok, advert} <- load_advert(actor, :delete, id) do
      Multi.new()
      |> Multi.delete(:advert, Advert.remove_image_changeset(advert))
      |> Uploader.put_unpersist_old_upload(:advert)
      |> ModerationLogs.put_log(:moderation_log, actor, fn %{advert: advert} ->
        {"Admin.Advert:delete", "/admin/adverts", "Deleted advert #{advert.id}"}
      end)
      |> Multi.transact()
      |> case do
        {:ok, %{advert: %Advert{} = advert}} ->
          {:ok, advert}

        {:error, :advert, %Ecto.Changeset{} = changeset, _changes} ->
          {:error, changeset}
      end
    end
  end

  @doc """
  Updates the image of the advert named by the `id`, on behalf of
  `actor`, running the image upload pipeline.

  On success a moderation log attributing the update to `actor` is written.

  ## Examples

      iex> update_advert_image(admin, advert_id, upload)
      {:ok, %Advert{}}

      iex> update_advert_image(admin, advert_id, nil)
      {:error, %Ecto.Changeset{}}

      iex> update_advert_image(admin, invalid_id, upload)
      {:error, :not_found}

      iex> update_advert_image(user, advert_id, upload)
      {:error, :unauthorized}

  """
  @spec update_advert_image(Actor.t(), Loader.integer_id(), PhilomenaMedia.Upload.t() | nil) ::
          {:ok, Advert.t()}
          | {:error, Authorization.write_error_reason() | :not_found | Ecto.Changeset.t()}
  def update_advert_image(%Actor{} = actor, id, upload) do
    with :ok <- verify_write_access(actor),
         {:ok, advert} <- load_advert(actor, :update_image, id) do
      advert_changeset =
        advert
        |> Advert.changeset()
        |> Uploader.analyze_upload(upload)

      Multi.new()
      |> Multi.update(:advert, advert_changeset)
      |> Uploader.put_persist_upload_and_unpersist_old(:advert)
      |> ModerationLogs.put_log(:moderation_log, actor, fn %{advert: advert} ->
        {"Admin.Advert.Image:update", "/admin/adverts", "Updated image for advert #{advert.id}"}
      end)
      |> Multi.transact()
      |> case do
        {:ok, %{advert: %Advert{} = advert}} ->
          {:ok, advert}

        {:error, :advert, %Ecto.Changeset{} = changeset, _changes} ->
          {:error, changeset}
      end
    end
  end

  @doc """
  Records batched advert impressions and clicks.
  """
  @spec record_counters(%{impressions: map(), clicks: map()}) :: :ok
  def record_counters(%{impressions: impressions, clicks: clicks}) do
    Enum.each(impressions, &increment_counter(&1, :impressions))
    Enum.each(clicks, &increment_counter(&1, :clicks))
    :ok
  end
end
