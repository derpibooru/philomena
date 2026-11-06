defmodule Philomena.DnpEntries do
  @moduledoc """
  Do-Not-Post listings, forms, and staff transitions.
  """

  import Ecto.Query, warn: false

  import Philomena.Authorization,
    only: [authorize: 3, verify_not_banned: 1, verify_write_access: 1]

  alias Philomena.Attribution.Actor
  alias Philomena.DnpEntries.{DnpEntry, DnpEntryForm, DnpEntryPage, DnpListing}
  alias Philomena.DnpEntries.{QueryBuilder, QueryForm}
  alias Philomena.Loader
  alias Philomena.ModerationLogs
  alias Philomena.ModerationLogs.Paths
  alias Philomena.ModNotes
  alias Philomena.Multi
  alias Philomena.Repo
  alias Philomena.Tags
  alias Philomena.Tags.Tag
  alias Philomena.Users.User

  defp dnp_entry_form(%DnpEntry{} = dnp_entry, selectable_tags, changeset \\ nil) do
    %DnpEntryForm{
      dnp_entry: dnp_entry,
      changeset: changeset || DnpEntry.changeset(dnp_entry),
      selectable_tags: selectable_tags
    }
  end

  defp linked_tags(%User{} = user) do
    user
    |> Repo.preload(:linked_tags)
    |> Map.fetch!(:linked_tags)
  end

  defp linked_tags(_user), do: []

  defp get_tag_from_params(params) do
    with {:ok, tag_id} <- DnpEntry.fetch_tag_id(params),
         {:ok, tag} <- Loader.fetch(Tag, tag_id) do
      tag
    else
      _ -> nil
    end
  end

  defp may_select_any_tag?(actor) do
    authorize(actor, :select_any_tag, DnpEntry) == :ok
  end

  defp nonempty_tags([]), do: {:error, :unauthorized}
  defp nonempty_tags(tags), do: {:ok, tags}

  defp selectable_tags(%Actor{user: user} = actor, default_tag) do
    if not is_nil(default_tag) and may_select_any_tag?(actor) do
      {:ok, [default_tag]}
    else
      user
      |> linked_tags()
      |> nonempty_tags()
    end
  end

  defp selected_tag_names(params, selectable_tags) do
    with {:ok, tag_id} <- DnpEntry.fetch_tag_id(params),
         %Tag{name: name} <- Enum.find(selectable_tags, &(&1.id == tag_id)) do
      [name]
    else
      _ -> []
    end
  end

  defp load_authorized_dnp_entry(actor, id, action) do
    Loader.fetch_and_authorize(DnpEntry, actor, action, id, [:tag])
  end

  @doc """
  Assembles the public or current-user DNP listing.

  A signed-in actor using the `"mine"` parameter receives their own entries
  ordered by creation time and a visible status column. Every other request
  receives only listed entries ordered by tag name. The viewer's linked tags
  accompany both views.

  ## Examples

      iex> list_dnp_entries(actor, %{"mine" => "1"}, pagination)
      %DnpListing{status_column: true}

  """
  @spec list_dnp_entries(Actor.t(), map(), Repo.pagination_params()) :: DnpListing.t()
  def list_dnp_entries(actor, params, pagination)

  def list_dnp_entries(%Actor{user: %User{} = user}, %{"mine" => _mine}, pagination) do
    entries =
      DnpEntry
      |> where(requesting_user_id: ^user.id)
      |> preload(:tag)
      |> order_by(asc: :created_at)
      |> Repo.paginate(pagination)

    %DnpListing{dnp_entries: entries, linked_tags: linked_tags(user), status_column: true}
  end

  def list_dnp_entries(%Actor{} = actor, _params, pagination) do
    entries =
      DnpEntry
      |> where(aasm_state: "listed")
      |> join(:inner, [d], t in Tag, on: d.tag_id == t.id)
      |> preload(:tag)
      |> order_by([_d, t], asc: t.name_in_namespace)
      |> Repo.paginate(pagination)

    %DnpListing{dnp_entries: entries, linked_tags: linked_tags(actor.user), status_column: false}
  end

  @doc """
  Loads the newest admin DNP entries authorized for `actor`.

  A list-valued `"states"` filter takes precedence over the text `"eq"`
  filter. Without either, active requests are listed.

  ## Examples

      iex> list_admin_dnp_entries(moderator, %{}, pagination)
      {:ok, %Scrivener.Page{}}

      iex> list_admin_dnp_entries(user, %{}, pagination)
      {:error, :unauthorized}

  """
  @spec list_admin_dnp_entries(Actor.t(), map(), Repo.pagination_params()) ::
          {:ok, Scrivener.Page.t(DnpEntry.t()), Ecto.Changeset.t()}
          | {:error, :unauthorized}
  def list_admin_dnp_entries(%Actor{} = actor, params, pagination) do
    with :ok <- authorize(actor, :index, DnpEntry) do
      {entries, changeset} =
        case QueryBuilder.search_dnp_entries(params) do
          {:ok, query, query_form} ->
            {Repo.paginate(query, pagination), QueryForm.changeset(query_form)}

          {:error, changeset} ->
            {Repo.paginate(where(DnpEntry, false), pagination), changeset}
        end

      {:ok, entries, changeset}
    end
  end

  @doc """
  Loads an authorized DNP page and any moderation notes visible to `actor`.

  IDs are parsed and loaded before instance authorization, so malformed and
  missing IDs are consistently not-found.

  ## Examples

      iex> show_dnp_entry(actor, "1", renderer)
      {:ok, %DnpEntryPage{}}

      iex> show_dnp_entry(actor, "not-an-id", renderer)
      {:error, :not_found}

  """
  @spec show_dnp_entry(Actor.t(), Loader.integer_id(), (list() -> list())) ::
          {:ok, DnpEntryPage.t()} | {:error, :not_found | :unauthorized}
  def show_dnp_entry(%Actor{} = actor, id, collection_renderer) do
    with {:ok, dnp_entry} <- load_authorized_dnp_entry(actor, id, :show) do
      mod_notes =
        case ModNotes.list_for_target(
               actor,
               {:dnp_entry, dnp_entry.id},
               collection_renderer
             ) do
          {:ok, notes} -> notes
          {:error, _reason} -> nil
        end

      {:ok, %DnpEntryPage{dnp_entry: dnp_entry, mod_notes: mod_notes}}
    end
  end

  @doc """
  Builds a new DNP request form on behalf of `actor`.

  A ban and the `:new` ability are checked before tag selection; a missing
  fingerprint is not. Normal
  users may select from verified linked tags; staff may request one arbitrary
  tag by ID. Malformed or missing privileged tag IDs are not-found.

  ## Examples

      iex> new_dnp_entry(actor, %{})
      {:ok, %DnpEntryForm{}}

      iex> new_dnp_entry(banned_actor, %{})
      {:error, :ban}

  """
  @spec new_dnp_entry(Actor.t(), map()) ::
          {:ok, DnpEntryForm.t()} | {:error, :ban | :unauthorized | :not_found}
  def new_dnp_entry(%Actor{} = actor, params) do
    with :ok <- verify_not_banned(actor),
         :ok <- authorize(actor, :new, DnpEntry),
         default_tag = get_tag_from_params(params),
         {:ok, tags} <- selectable_tags(actor, default_tag) do
      {:ok, dnp_entry_form(%DnpEntry{}, tags)}
    end
  end

  @doc """
  Creates a DNP request using the same access and tag-selection policy as the
  new form. Validation failures return a `DnpEntryForm`.

  ## Examples

      iex> create_dnp_entry(actor, attrs)
      {:ok, %DnpEntry{}}

      iex> create_dnp_entry(actor, invalid_attrs)
      {:error, %DnpEntryForm{}}

  """
  @spec create_dnp_entry(Actor.t(), map()) ::
          {:ok, DnpEntry.t()}
          | {:error, DnpEntryForm.t()}
          | {:error, :ban | :unauthorized | :not_found}
  def create_dnp_entry(%Actor{user: user} = actor, params) do
    with :ok <- verify_write_access(actor),
         :ok <- authorize(actor, :create, DnpEntry),
         default_tag = get_tag_from_params(params),
         {:ok, selectable_tags} <- selectable_tags(actor, default_tag) do
      selectable_tag_ids = Enum.map(selectable_tags, & &1.id)
      tag_names = selected_tag_names(params, selectable_tags)

      Multi.new()
      |> Tags.put_canonicalize_tag_name_sets([{:tag, tag_names, []}])
      |> Multi.insert(:dnp_entry, fn
        %{canonical_tags: %{tag: [tag]}} ->
          DnpEntry.creation_changeset(%DnpEntry{}, params, user, tag)

        %{canonical_tags: %{tag: []}} ->
          DnpEntry.creation_changeset(%DnpEntry{}, params, user, selectable_tag_ids)
      end)
      |> Multi.transact_with_automatic_retry()
      |> case do
        {:ok, %{dnp_entry: %DnpEntry{} = dnp_entry}} ->
          {:ok, dnp_entry}

        {:error, :dnp_entry, %Ecto.Changeset{} = changeset, _changes} ->
          {:error, dnp_entry_form(changeset.data, selectable_tags, changeset)}
      end
    end
  end

  @doc """
  Loads an existing DNP entry edit form.

  The entry is loaded before instance authorization. Its current tag is the
  default moderator selection, so a bare edit URL is sufficient. An explicit
  privileged tag ID, if provided, is loaded safely.

  ## Examples

      iex> edit_dnp_entry(moderator, "1")
      {:ok, %DnpEntryForm{}}

      iex> edit_dnp_entry(user, "1")
      {:error, :unauthorized}

  """
  @spec edit_dnp_entry(Actor.t(), Loader.integer_id()) ::
          {:ok, DnpEntryForm.t()} | {:error, :ban | :unauthorized | :not_found}
  def edit_dnp_entry(%Actor{} = actor, id) do
    with :ok <- verify_not_banned(actor),
         {:ok, dnp_entry} <- load_authorized_dnp_entry(actor, id, :edit),
         {:ok, tags} <- selectable_tags(actor, dnp_entry.tag) do
      {:ok, dnp_entry_form(dnp_entry, tags)}
    end
  end

  @doc """
  Updates an existing DNP entry using the same access and tag-selection policy
  as the edit form. Validation failures return a `DnpEntryForm`.

  ## Examples

      iex> update_dnp_entry(moderator, "1", attrs)
      {:ok, %DnpEntry{}}

      iex> update_dnp_entry(moderator, "1", invalid_attrs)
      {:error, %DnpEntryForm{}}

  """
  @spec update_dnp_entry(Actor.t(), Loader.integer_id(), map()) ::
          {:ok, DnpEntry.t()}
          | {:error, DnpEntryForm.t()}
          | {:error, :ban | :unauthorized | :not_found}
  def update_dnp_entry(%Actor{} = actor, id, params) do
    with :ok <- verify_write_access(actor),
         {:ok, dnp_entry} <- load_authorized_dnp_entry(actor, id, :update),
         {:ok, selectable_tags} <- selectable_tags(actor, dnp_entry.tag) do
      selectable_tag_ids = Enum.map(selectable_tags, & &1.id)
      tag_names = selected_tag_names(params, selectable_tags)

      Multi.new()
      |> Tags.put_canonicalize_tag_name_sets([{:tag, tag_names, []}])
      |> Multi.update(:dnp_entry, fn
        %{canonical_tags: %{tag: [tag]}} ->
          DnpEntry.update_changeset(dnp_entry, params, tag)

        %{canonical_tags: %{tag: []}} ->
          DnpEntry.update_changeset(dnp_entry, params, selectable_tag_ids)
      end)
      |> Multi.transact_with_automatic_retry()
      |> case do
        {:ok, %{dnp_entry: %DnpEntry{} = dnp_entry}} ->
          {:ok, dnp_entry}

        {:error, :dnp_entry, %Ecto.Changeset{} = changeset, _changes} ->
          {:error, dnp_entry_form(dnp_entry, selectable_tags, changeset)}
      end
    end
  end

  @doc """
  Transitions one DNP entry on behalf of staff.

  The entry is locked, loaded, and authorized with the distinct `:transition`
  ability. The state update and moderation log commit atomically.

  ## Examples

      iex> create_dnp_entry_transition(moderator, "1", "listed")
      {:ok, %DnpEntry{aasm_state: "listed"}}

      iex> create_dnp_entry_transition(user, "1", "listed")
      {:error, :unauthorized}

  """
  @spec create_dnp_entry_transition(Actor.t(), Loader.integer_id(), String.t() | nil) ::
          {:ok, DnpEntry.t()}
          | {:error, :ban | :unauthorized | :not_found | Ecto.Changeset.t()}
  def create_dnp_entry_transition(%Actor{user: user} = actor, id, new_state) do
    with :ok <- verify_write_access(actor),
         {:ok, dnp_entry} <- load_authorized_dnp_entry(actor, id, :transition) do
      dnp_entry_changeset = DnpEntry.transition_changeset(dnp_entry, user, new_state)

      Multi.new()
      |> Multi.update(:dnp_entry, dnp_entry_changeset)
      |> ModerationLogs.put_log(
        :moderation_log,
        actor,
        fn %{dnp_entry: dnp_entry} ->
          {
            "Admin.DnpEntry.Transition:create",
            Paths.dnp_entry_path(dnp_entry),
            "#{String.capitalize(dnp_entry.aasm_state)} DNP entry #{dnp_entry.id} on #{dnp_entry.tag.name}"
          }
        end
      )
      |> Multi.transact()
      |> case do
        {:ok, %{dnp_entry: %DnpEntry{} = dnp_entry}} ->
          {:ok, dnp_entry}

        {:error, :dnp_entry, %Ecto.Changeset{} = changeset, _changes} ->
          {:error, changeset}
      end
    end
  end

  @doc """
  Repoints DNP entries from one tag to another inside `multi`.

  Tag aliasing uses this boundary so the DnpEntries context owns its table
  update and the operation remains coupled to the alias transaction.
  """
  @spec put_replace_tag(Multi.t(), Multi.name(), integer(), integer()) :: Multi.t()
  def put_replace_tag(%Multi{} = multi, step, source_tag_id, target_tag_id) do
    query =
      DnpEntry
      |> where(tag_id: ^source_tag_id)
      |> update(set: [tag_id: ^target_tag_id])

    Multi.update_all(multi, step, query, [])
  end

  @doc """
  Loads the DNP entries needed to validate an image's canonical tags inside
  the caller's transaction.

  The canonical tag step must contain an `:added_tags` list. The resulting
  preloaded tags are stored under `dnp_step` for the image changeset to use.
  """
  @spec put_dnp_tags(Multi.t(), Multi.name(), Multi.name()) :: Multi.t()
  def put_dnp_tags(%Multi{} = multi, dnp_step, canonical_tags_step) do
    Multi.all(multi, dnp_step, fn %{^canonical_tags_step => %{added_tags: tags}} ->
      tag_names = Enum.map(tags, & &1.name)

      Tag
      |> from(as: :tag)
      |> where([t], t.name in ^tag_names)
      |> where(exists(where(DnpEntry, [d], d.tag_id == parent_as(:tag).id)))
      |> preload(dnp_entries: [tag: :verified_links])
    end)
  end

  @doc """
  Returns the count of active DNP requests when `actor` may view the admin DNP
  index, otherwise `nil`.

  ## Examples

      iex> count_dnp_entries(moderator)
      3

      iex> count_dnp_entries(user)
      nil

  """
  @spec count_dnp_entries(Actor.t()) :: non_neg_integer() | nil
  def count_dnp_entries(%Actor{} = actor) do
    case authorize(actor, :index, DnpEntry) do
      :ok ->
        DnpEntry
        |> where([dnp], dnp.aasm_state in ["requested", "claimed", "acknowledged"])
        |> Repo.aggregate(:count)

      {:error, :unauthorized} ->
        nil
    end
  end
end
