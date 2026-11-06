defmodule Philomena.ModNotes do
  @moduledoc """
  Staff notes attached to users, reports, and DNP entries.

  Target selection is represented by a typed Target descriptor and every
  target is loaded and separately authorized. Writes are attributed
  to the acting staff member and transactionally coupled to their
  moderation audit record.
  """

  import Ecto.Query, warn: false

  import Philomena.Authorization,
    only: [authorize: 3, verify_not_banned: 1, verify_write_access: 1]

  alias Philomena.IntegerId
  alias Philomena.Multi
  alias Philomena.Attribution.Actor
  alias Philomena.Loader
  alias Philomena.ModerationLogs
  alias Philomena.ModNotes.ModNote
  alias Philomena.ModNotes.Target
  alias Philomena.Repo

  @embedded_page_size 250

  defp fetch_and_authorize_target(actor, %Target{} = target, action) do
    Loader.fetch_and_authorize(target.schema, actor, action, target.value)
  end

  defp target_query(%Target{} = target) do
    from note in ModNote,
      where: field(note, ^target.column) == ^target.value
  end

  defp ordered_notes(queryable) do
    queryable
    |> preload(:moderator)
    |> order_by(desc: :id)
  end

  defp render_notes(notes, collection_renderer) do
    preloaded = Repo.preload(notes, ModNote.target_preloads())
    rendered = collection_renderer.(preloaded)
    Enum.zip(preloaded, rendered)
  end

  defp paginate_notes(queryable, collection_renderer, pagination) do
    page =
      queryable
      |> ordered_notes()
      |> Repo.paginate(pagination)

    %{page | entries: render_notes(page.entries, collection_renderer)}
  end

  defp load_mod_note(actor, id, action) do
    Loader.fetch_and_authorize(ModNote, actor, action, id, ModNote.target_preloads())
  end

  @doc """
  Returns up to 250 newest notes for `target`, rendered for an embedded page.

  The actor must be allowed to index notes and to view notes for the safely
  loaded target. Malformed and missing target IDs are `{:error, :not_found}`.
  History is retained indefinitely, but the returned list is bounded to 250.

  ## Examples

      iex> list_for_target(moderator, {:user, "12"}, renderer)
      {:ok, [{%ModNote{}, "rendered body"}]}

      iex> list_for_target(user, {:user, "12"}, renderer)
      {:error, :unauthorized}

  """
  @spec list_for_target(Actor.t(), {atom(), IntegerId.integer_id()}, (list(ModNote.t()) ->
                                                                        list(term()))) ::
          {:ok, [{ModNote.t(), term()}]} | {:error, :not_found | :unauthorized}
  def list_for_target(%Actor{} = actor, {type, id}, collection_renderer)
      when type in [:user, :report, :dnp_entry] do
    with :ok <- authorize(actor, :index, ModNote),
         {:ok, target} <- Target.from_type_and_id(type, id),
         {:ok, _record} <-
           fetch_and_authorize_target(actor, target, :show_mod_notes) do
      notes =
        target
        |> target_query()
        |> ordered_notes()
        |> limit(@embedded_page_size)
        |> Repo.all()

      {:ok, render_notes(notes, collection_renderer)}
    end
  end

  @doc """
  Loads the paginated staff note index, optionally scoped to one target.

  A target filter is one of `user_id`, `report_id`, or `dnp_entry_id`, and is
  authorized for `:show_mod_notes`. Multiple, malformed, or missing targets
  act as if no filter was provided. With no filter, all notes are returned
  newest first.

  ## Examples

      iex> list_mod_notes(moderator, %{"user_id" => "12"}, renderer, pagination)
      {:ok, %Scrivener.Page{}}

      iex> list_mod_notes(user, %{}, renderer, pagination)
      {:error, :unauthorized}

  """
  @spec list_mod_notes(
          Actor.t(),
          map(),
          (list(ModNote.t()) -> list(term())),
          Repo.pagination_params()
        ) :: {:ok, Scrivener.Page.t()} | {:error, :not_found | :unauthorized}
  def list_mod_notes(%Actor{} = actor, params, collection_renderer, pagination) do
    with :ok <- authorize(actor, :index, ModNote) do
      with {:ok, target} <- Target.from_params(params),
           {:ok, _record} <- fetch_and_authorize_target(actor, target, :show_mod_notes) do
        {:ok, paginate_notes(target_query(target), collection_renderer, pagination)}
      else
        _ ->
          {:ok, paginate_notes(ModNote, collection_renderer, pagination)}
      end
    end
  end

  @doc """
  Builds a new-note changeset for the target selected in `params`.

  The target is loaded and authorized with `:annotate`.

  ## Examples

      iex> new_mod_note(moderator, %{"report_id" => "7"})
      {:ok, %Ecto.Changeset{}}

      iex> new_mod_note(user, %{})
      {:error, :unauthorized}

  """
  @spec new_mod_note(Actor.t(), map()) ::
          {:ok, Ecto.Changeset.t()} | {:error, :ban | :not_found | :unauthorized}
  def new_mod_note(%Actor{user: moderator} = actor, params) do
    with :ok <- verify_not_banned(actor),
         :ok <- authorize(actor, :new, ModNote),
         {:ok, target} <- Target.from_params(params),
         {:ok, _} <- fetch_and_authorize_target(actor, target, :annotate) do
      {:ok,
       %ModNote{moderator_id: moderator.id}
       |> ModNote.creation_changeset(%{}, Target.to_changes(target))}
    end
  end

  @doc """
  Creates an attributed note and its moderation log in one transaction.

  The target is loaded and authorized with `:annotate`.

  ## Examples

      iex> create_mod_note(moderator, %{"user_id" => "12", "body" => "Watching"})
      {:ok, %ModNote{}}

      iex> create_mod_note(user, attrs)
      {:error, :unauthorized}

  """
  @spec create_mod_note(Actor.t(), map()) ::
          {:ok, ModNote.t()}
          | {:error, :ban | :not_found | :unauthorized | Ecto.Changeset.t()}
  def create_mod_note(%Actor{user: moderator} = actor, attrs) do
    with :ok <- verify_write_access(actor),
         :ok <- authorize(actor, :create, ModNote),
         {:ok, target} <- Target.from_params(attrs),
         {:ok, _} <- fetch_and_authorize_target(actor, target, :annotate) do
      mod_note_changeset =
        %ModNote{moderator_id: moderator.id}
        |> ModNote.creation_changeset(attrs, Target.to_changes(target))

      Multi.new()
      |> Multi.insert(:mod_note, mod_note_changeset)
      |> ModerationLogs.put_log(
        :moderation_log,
        actor,
        "ModNote:create",
        "/admin/mod_notes",
        "Created mod note for #{Target.label(target)}"
      )
      |> Multi.transact()
      |> case do
        {:ok, %{mod_note: %ModNote{} = mod_note}} ->
          {:ok, mod_note}

        {:error, :mod_note, %Ecto.Changeset{} = changeset, _changes} ->
          {:error, changeset}
      end
    end
  end

  @doc """
  Loads an authorized note and edit changeset for `actor`.

  ## Examples

      iex> edit_mod_note(moderator, "1")
      {:ok, {%ModNote{}, %Ecto.Changeset{}}}

      iex> edit_mod_note(user, "1")
      {:error, :unauthorized}

  """
  @spec edit_mod_note(Actor.t(), Loader.integer_id()) ::
          {:ok, {ModNote.t(), Ecto.Changeset.t()}}
          | {:error, :ban | :not_found | :unauthorized}
  def edit_mod_note(%Actor{} = actor, id) do
    with :ok <- verify_not_banned(actor),
         {:ok, mod_note} <- load_mod_note(actor, id, :edit) do
      {:ok, {mod_note, ModNote.changeset(mod_note)}}
    end
  end

  @doc """
  Updates a note and appends its audit record in the same transaction.

  ## Examples

      iex> update_mod_note(moderator, "1", %{"body" => "Updated"})
      {:ok, %ModNote{}}

      iex> update_mod_note(user, "1", attrs)
      {:error, :unauthorized}

  """
  @spec update_mod_note(Actor.t(), Loader.integer_id(), map()) ::
          {:ok, ModNote.t()}
          | {:error, :ban | :not_found | :unauthorized | Ecto.Changeset.t()}
  def update_mod_note(%Actor{} = actor, id, attrs) do
    with :ok <- verify_write_access(actor),
         {:ok, mod_note} <- load_mod_note(actor, id, :update) do
      mod_note_changeset = ModNote.changeset(mod_note, attrs)

      Multi.new()
      |> Multi.update(:mod_note, mod_note_changeset)
      |> ModerationLogs.put_log(
        :moderation_log,
        actor,
        "ModNote:update",
        "/admin/mod_notes/#{mod_note.id}",
        "Updated mod note #{mod_note.id}"
      )
      |> Multi.transact()
      |> case do
        {:ok, %{mod_note: %ModNote{} = mod_note}} ->
          {:ok, mod_note}

        {:error, :mod_note, %Ecto.Changeset{} = changeset, _changes} ->
          {:error, changeset}
      end
    end
  end

  @doc """
  Deletes a note and appends its audit record in the same transaction.

  ## Examples

      iex> delete_mod_note(moderator, "1")
      {:ok, %ModNote{}}

      iex> delete_mod_note(user, "1")
      {:error, :unauthorized}

  """
  @spec delete_mod_note(Actor.t(), Loader.integer_id()) ::
          {:ok, ModNote.t()}
          | {:error, :ban | :not_found | :unauthorized | Ecto.Changeset.t()}
  def delete_mod_note(%Actor{} = actor, id) do
    with :ok <- verify_write_access(actor),
         {:ok, mod_note} <- load_mod_note(actor, id, :delete) do
      Multi.new()
      |> Multi.delete(:mod_note, mod_note)
      |> ModerationLogs.put_log(
        :moderation_log,
        actor,
        "ModNote:delete",
        "/admin/mod_notes/#{mod_note.id}",
        "Deleted mod note #{mod_note.id}"
      )
      |> Multi.transact()
      |> case do
        {:ok, %{mod_note: %ModNote{} = mod_note}} ->
          {:ok, mod_note}

        {:error, :mod_note, %Ecto.Changeset{} = changeset, _changes} ->
          {:error, changeset}
      end
    end
  end
end
