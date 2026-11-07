defmodule Philomena.Channels do
  @moduledoc """
  Livestream discovery, staff-managed channel configuration, and per-user
  subscription/read state.
  """

  import Ecto.Query, warn: false

  import Philomena.Authorization,
    only: [authorize: 3, verify_not_banned: 1, verify_write_access: 1]

  alias Philomena.Attribution.Actor
  alias Philomena.Channels.AutomaticUpdater
  alias Philomena.Channels.Channel
  alias Philomena.Channels.QueryBuilder
  alias Philomena.Channels.QueryForm
  alias Philomena.Loader
  alias Philomena.Multi
  alias Philomena.Notifications
  alias Philomena.Repo
  alias Philomena.Tags

  use Philomena.Subscriptions,
    id_name: :channel_id

  defp change_channel(%Channel{} = channel, attrs, canonical_tags) do
    changeset = Channel.changeset(channel, attrs)

    if is_nil(channel.artist_tag) do
      Channel.artist_tag_changeset(changeset, nil, nil)
    else
      Channel.artist_tag_changeset(changeset, channel.artist_tag, List.first(canonical_tags))
    end
  end

  defp clear_notification_for(%Channel{} = channel, user) do
    Notifications.clear_channel_live(channel, user)
    :ok
  end

  defp load_channel(actor, id, action, preloads \\ []) do
    Loader.fetch_and_authorize(Channel, actor, action, id, preloads)
  end

  defp maybe_show_nsfw(query, true), do: query
  defp maybe_show_nsfw(query, _falsy), do: where(query, nsfw: false)

  defp channels_query(query, show_nsfw?) do
    query
    |> maybe_show_nsfw(show_nsfw?)
    |> where([c], not is_nil(c.last_fetched_at))
    |> order_by(desc: :is_live, asc: :title)
    |> preload([:associated_artist_tag])
  end

  @doc """
  Updates all tracked channels for which an automatic fetch scheme is known.

  Raises when the updater cannot maintain its fetch invariant.

  ## Examples

      iex> update_tracked_channels!()
      :ok

  """
  @spec update_tracked_channels!() :: :ok
  def update_tracked_channels! do
    AutomaticUpdater.update_tracked_channels!()
  end

  @doc """
  Counts channels which are currently live.

  This aggregate includes live channels even when they have not yet been
  stamped by the automatic fetcher.

  ## Examples

      iex> count_live_channels()
      2

  """
  @spec count_live_channels() :: non_neg_integer()
  def count_live_channels do
    Channel
    |> where(is_live: true)
    |> Repo.aggregate(:count)
  end

  @doc """
  Loads the livestream listing for the home page.

  Only channels the fetcher has stamped (`last_fetched_at` set) are listed,
  ordered live-first and then by title. `show_nsfw?` includes NSFW channels.

  ## Examples

      iex> list_front_page_channels(actor, false, 6)
      [%Channel{}, ...]

  """
  @spec list_front_page_channels(Actor.t(), boolean(), pos_integer()) ::
          [Channel.t()]
  def list_front_page_channels(%Actor{} = _actor, show_nsfw?, strip_size) do
    Channel
    |> channels_query(show_nsfw?)
    |> limit(^strip_size)
    |> Repo.all()
  end

  @doc """
  Loads the livestream listing and the acting user's subscription state.

  Only channels the fetcher has stamped (`last_fetched_at` set) are listed,
  ordered live-first and then by title. `show_nsfw?` includes NSFW channels;
  a non-empty `"cq"` matches title, short name, or artist tag name. Subscription
  state is scoped to the actor's user and is empty for an anonymous actor.

  ## Examples

      iex> list_channels(actor, false, %{"cq" => "pony"}, pagination)
      {:ok, %Scrivener.Page{}, %{12 => true}, %Ecto.Changeset{}}

  """
  @spec list_channels(Actor.t(), boolean(), map(), Repo.pagination_params()) ::
          {:ok, Scrivener.Page.t(), %{optional(integer()) => true}, Ecto.Changeset.t()}
          | {:error, Ecto.Changeset.t()}
  def list_channels(%Actor{} = actor, show_nsfw?, params, pagination) do
    with {:ok, query, query_form} <- QueryBuilder.build_query(params) do
      channels =
        query
        |> channels_query(show_nsfw?)
        |> Repo.paginate(pagination)

      {:ok, channels, subscriptions(channels, actor.user), QueryForm.changeset(query_form)}
    end
  end

  @doc """
  Loads the channel named by `id` for a public visit and clears the acting
  user's live notification when signed in.

  The named `:visit` ability permits anonymous browsing. Malformed and missing
  IDs are always `{:error, :not_found}`.

  ## Examples

      iex> show_channel(user, "1")
      {:ok, %Channel{}}

      iex> show_channel(actor, "999999999")
      {:error, :not_found}

  """
  @spec show_channel(Actor.t(), Loader.integer_id()) ::
          {:ok, Channel.t()} | {:error, :not_found | :unauthorized}
  def show_channel(%Actor{} = actor, id) do
    with {:ok, channel} <- load_channel(actor, id, :visit) do
      clear_notification_for(channel, actor.user)
      {:ok, channel}
    end
  end

  @doc """
  Clears the acting user's live notification for the channel named by the
  `id`, returning the channel.

  This authenticated read-state operation authorizes `:mark_read`. It is
  specifically exempt from `verify_write_access/1`.

  ## Examples

      iex> create_channel_read(user, "1")
      {:ok, %Channel{}}

      iex> create_channel_read(user, "999999999")
      {:error, :not_found}

  """
  @spec create_channel_read(Actor.t(), Loader.integer_id()) ::
          {:ok, Channel.t()} | {:error, :not_found | :unauthorized}
  def create_channel_read(%Actor{} = actor, id) do
    with {:ok, channel} <- load_channel(actor, id, :mark_read) do
      clear_notification_for(channel, actor.user)
      {:ok, channel}
    end
  end

  @doc """
  Builds the changeset for a new channel, on behalf of `actor`.

  ## Examples

      iex> new_channel(moderator)
      {:ok, %Ecto.Changeset{}}

      iex> new_channel(user)
      {:error, :unauthorized}

  """
  @spec new_channel(Actor.t()) ::
          {:ok, Ecto.Changeset.t()} | {:error, :ban | :unauthorized}
  def new_channel(%Actor{} = actor) do
    with :ok <- verify_not_banned(actor),
         :ok <- authorize(actor, :new, Channel) do
      {:ok, Channel.changeset(%Channel{})}
    end
  end

  @doc """
  Creates a channel on behalf of `actor`.

  An optional artist tag can be specified in the `"artist_tag"` attribute.

  ## Examples

      iex> create_channel(moderator, %{"type" => "PicartoChannel", "short_name" => "x"})
      {:ok, %Channel{}}

      iex> create_channel(moderator, invalid_params)
      {:error, %Ecto.Changeset{}}

      iex> create_channel(user, channel_params)
      {:error, :unauthorized}

  """
  @spec create_channel(Actor.t(), map()) ::
          {:ok, Channel.t()} | {:error, :ban | :unauthorized | Ecto.Changeset.t()}
  def create_channel(%Actor{} = actor, attrs) do
    with :ok <- verify_write_access(actor),
         :ok <- authorize(actor, :create, Channel),
         {:ok, channel} <-
           %Channel{}
           |> Channel.artist_tag_name_changeset(attrs)
           |> Ecto.Changeset.apply_action(:create) do
      tag_names = List.wrap(channel.artist_tag)

      Multi.new()
      |> Tags.put_canonicalize_tag_name_sets([{:artist_tag, tag_names, []}])
      |> Multi.insert(:channel, fn %{canonical_tags: %{artist_tag: tags}} ->
        change_channel(channel, attrs, tags)
      end)
      |> Multi.transact_with_automatic_retry()
      |> case do
        {:ok, %{channel: %Channel{} = channel}} ->
          {:ok, channel}

        {:error, :channel, %Ecto.Changeset{} = changeset, _changes} ->
          {:error, changeset}
      end
    end
  end

  @doc """
  Loads the channel named by the `id` for editing, on behalf of
  `actor`, pairing it with a change-tracking changeset.

  ## Examples

      iex> edit_channel(moderator, "1")
      {:ok, {%Channel{}, %Ecto.Changeset{}}}

      iex> edit_channel(moderator, "999999999")
      {:error, :not_found}

      iex> edit_channel(user, "1")
      {:error, :unauthorized}

  """
  @spec edit_channel(Actor.t(), Loader.integer_id()) ::
          {:ok, {Channel.t(), Ecto.Changeset.t()}}
          | {:error, :ban | :not_found | :unauthorized}
  def edit_channel(%Actor{} = actor, id) do
    with :ok <- verify_not_banned(actor),
         {:ok, channel} <- load_channel(actor, id, :edit) do
      {:ok, {channel, Channel.changeset(channel)}}
    end
  end

  @doc """
  Updates the channel named by the `id`, on behalf of `actor`.

  On success, only `:type` and `:short_name` are applied.
  Fetcher-managed fields are ignored.

  ## Examples

      iex> update_channel(moderator, "1", %{"short_name" => "renamed"})
      {:ok, %Channel{}}

      iex> update_channel(moderator, "1", invalid_params)
      {:error, %Ecto.Changeset{}}

      iex> update_channel(moderator, "999999999", channel_params)
      {:error, :not_found}

      iex> update_channel(user, "1", channel_params)
      {:error, :unauthorized}

  """
  @spec update_channel(Actor.t(), Loader.integer_id(), map()) ::
          {:ok, Channel.t()}
          | {:error, :ban | :not_found | :unauthorized | Ecto.Changeset.t()}
  def update_channel(%Actor{} = actor, id, attrs) do
    with :ok <- verify_write_access(actor),
         {:ok, channel} <- load_channel(actor, id, :update, [:associated_artist_tag]),
         {:ok, channel} <-
           channel
           |> Channel.artist_tag_name_changeset(attrs)
           |> Ecto.Changeset.apply_action(:update) do
      tag_names = List.wrap(channel.artist_tag)

      Multi.new()
      |> Tags.put_canonicalize_tag_name_sets([{:artist_tag, tag_names, []}])
      |> Multi.update(:channel, fn %{canonical_tags: %{artist_tag: tags}} ->
        change_channel(channel, attrs, tags)
      end)
      |> Multi.transact_with_automatic_retry()
      |> case do
        {:ok, %{channel: %Channel{} = channel}} ->
          {:ok, channel}

        {:error, :channel, %Ecto.Changeset{} = changeset, _changes} ->
          {:error, changeset}
      end
    end
  end

  @doc """
  Updates channel state from the automatic updater.

  This function is not request-facing and performs no authorization.

  ## Examples

      iex> update_fetch_state(channel, %{field: new_value})
      {:ok, %Channel{}}

      iex> update_fetch_state(channel, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  @spec update_fetch_state(Channel.t(), map()) ::
          {:ok, Channel.t()} | {:error, Ecto.Changeset.t()}
  def update_fetch_state(%Channel{} = channel, attrs) do
    channel
    |> Channel.update_changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes the channel named by the `id`, on behalf of `actor`.

  ## Examples

      iex> delete_channel(moderator, "1")
      {:ok, %Channel{}}

  """
  @spec delete_channel(Actor.t(), Loader.integer_id()) ::
          {:ok, Channel.t()} | {:error, :ban | :not_found | :unauthorized}
  def delete_channel(%Actor{} = actor, id) do
    with :ok <- verify_write_access(actor),
         {:ok, channel} <- load_channel(actor, id, :delete) do
      Repo.delete(channel)
    end
  end

  @doc """
  Subscribes `actor` to the channel named by the `id`.

  Repeated subscription is an idempotent success. Unexpected persistence
  failures are returned as changeset errors.

  Subscription management is deliberately exempt from
  `verify_write_access/1`; channel visibility and subscription authorization
  still apply.

  ## Examples

      iex> create_channel_subscription(user, "1")
      {:ok, %Channel{}}

      iex> create_channel_subscription(anonymous_actor, "1")
      {:error, :unauthorized}

      iex> create_channel_subscription(user, "999999999")
      {:error, :not_found}

  """
  @spec create_channel_subscription(Actor.t(), Loader.integer_id()) ::
          {:ok, Channel.t()}
          | {:error, :not_found | :unauthorized | Ecto.Changeset.t()}
  def create_channel_subscription(%Actor{} = actor, id) do
    with {:ok, channel} <- load_channel(actor, id, :subscribe),
         {:ok, _subscription} <- create_subscription(channel, actor.user) do
      {:ok, channel}
    end
  end

  @doc """
  Unsubscribes `actor` from the channel named by the `id`.

  Repeated unsubscription is an idempotent success and also clears any live
  notification for the channel. Subscription management is deliberately
  exempt from `verify_write_access/1`; channel visibility and subscription
  authorization still apply.

  ## Examples

      iex> delete_channel_subscription(user, "1")
      {:ok, %Channel{}}

      iex> delete_channel_subscription(anonymous_actor, "1")
      {:error, :unauthorized}

      iex> delete_channel_subscription(user, "999999999")
      {:error, :not_found}

  """
  @spec delete_channel_subscription(Actor.t(), Loader.integer_id()) ::
          {:ok, Channel.t()} | {:error, :not_found | :unauthorized}
  def delete_channel_subscription(%Actor{} = actor, id) do
    with {:ok, channel} <- load_channel(actor, id, :unsubscribe),
         {:ok, _subscription} <- delete_subscription(channel, actor.user) do
      clear_notification_for(channel, actor.user)
      {:ok, channel}
    end
  end

  @doc """
  Repoints artist associations from an aliased tag to its target inside `multi`.
  """
  @spec put_replace_artist_tag(Multi.t(), Multi.name(), integer(), integer()) :: Multi.t()
  def put_replace_artist_tag(%Multi{} = multi, step, source_tag_id, target_tag_id) do
    query =
      Channel
      |> where(associated_artist_tag_id: ^source_tag_id)
      |> update(set: [associated_artist_tag_id: ^target_tag_id])

    Multi.update_all(multi, step, query, [])
  end

  @doc """
  Marks tracked channels for a provider offline when they are absent from the
  provider's current live name set.
  """
  @spec mark_provider_channels_offline(String.t(), [String.t()], DateTime.t()) ::
          {non_neg_integer(), nil}
  def mark_provider_channels_offline(provider_name, channel_names, now) do
    query =
      from channel in Channel,
        where: channel.type == ^provider_name and channel.short_name not in ^channel_names,
        update: [set: [is_live: false, updated_at: ^now]]

    Repo.update_all(query, [])
  end
end
