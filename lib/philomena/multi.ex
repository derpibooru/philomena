defmodule Philomena.Multi do
  @moduledoc """
  `m:Ecto.Multi` wrapper with locking utilities and deferred action semantics.
  """

  import Ecto.Query, only: [lock: 2]

  @enforce_keys [:multi]
  defstruct [:multi]

  @type t :: %__MODULE__{
          multi: Ecto.Multi.t()
        }

  @type name :: Ecto.Multi.name()
  @type changes :: Ecto.Multi.changes()
  @type failure :: Ecto.Multi.failure()

  @doc """
  Runs a query and stores all results in the Multi.

  The `name` must be unique within the Multi.

  The remaining arguments and options are the same as in `c:Ecto.Repo.all/2`.

  ## Example

      Multi.new()
      |> Multi.all(:all, Post)
      |> Multi.transact()

      Multi.new()
      |> Multi.all(:all, fn _changes -> Post end)
      |> Multi.transact()

  """
  @spec all(
          t(),
          Ecto.Multi.name(),
          queryable :: Ecto.Queryable.t() | (Ecto.Multi.changes() -> Ecto.Queryable.t()),
          opts :: Keyword.t()
        ) :: t()
  def all(%__MODULE__{} = multi, name, queryable_or_fun, opts \\ []) do
    update_in(multi.multi, &Ecto.Multi.all(&1, name, queryable_or_fun, opts))
  end

  @doc """
  Appends the second Multi to the first.

  All names must be unique within both structures.

  ## Example

      iex> lhs = Multi.new() |> Multi.run(:left, fn _, changes -> {:ok, changes} end)
      iex> rhs = Multi.new() |> Multi.run(:right, fn _, changes -> {:error, changes} end)
      iex> Multi.append(lhs, rhs) |> Multi.to_list |> Keyword.keys
      [:left, :right]

  """
  @spec append(t(), t()) :: t()
  def append(%__MODULE__{} = lhs, %__MODULE__{} = rhs) do
    update_in(lhs.multi, &Ecto.Multi.append(&1, rhs.multi))
  end

  @doc """
  Adds a delete operation to the Multi.

  The `name` must be unique within the Multi.

  The remaining arguments and options are the same as in `c:Ecto.Repo.delete/2`.

  ## Example

      post = MyApp.Repo.get!(Post, 1)
      Multi.new()
      |> Multi.delete(:delete, post)
      |> Multi.transact()

      Multi.new()
      |> Multi.run(:post, fn repo, _changes ->
        case repo.get(Post, 1) do
          nil -> {:error, :not_found}
          post -> {:ok, post}
        end
      end)
      |> Multi.delete(:delete, fn %{post: post} ->
        # Others validations
        post
      end)
      |> Multi.transact()

  """
  @spec delete(
          t(),
          Ecto.Multi.name(),
          Ecto.Changeset.t()
          | Ecto.Schema.t()
          | (Ecto.Multi.changes() -> Ecto.Changeset.t() | Ecto.Schema.t()),
          Keyword.t()
        ) :: t
  def delete(%__MODULE__{} = multi, name, changeset_or_struct_fun, opts \\ []) do
    update_in(multi.multi, &Ecto.Multi.delete(&1, name, changeset_or_struct_fun, opts))
  end

  @doc """
  Adds a `delete_all` operation to the Multi.

  Accepts the same arguments and options as `c:Ecto.Repo.delete_all/2`.

  ## Example

      queryable = from(p in Post, where: p.id < 5)
      Multi.new()
      |> Multi.delete_all(:delete_all, queryable)
      |> Multi.transact()

      Multi.new()
      |> Multi.run(:post, fn repo, _changes ->
        case repo.get(Post, 1) do
          nil -> {:error, :not_found}
          post -> {:ok, post}
        end
      end)
      |> Multi.delete_all(:delete_all, fn %{post: post} ->
        # Others validations
        from(c in Comment, where: c.post_id == ^post.id)
      end)
      |> Multi.transact()

  """
  @spec delete_all(
          t(),
          Ecto.Multi.name(),
          Ecto.Queryable.t() | (Ecto.Multi.changes() -> Ecto.Queryable.t()),
          Keyword.t()
        ) :: t()
  def delete_all(%__MODULE__{} = multi, name, queryable_or_fun, opts \\ []) do
    update_in(multi.multi, &Ecto.Multi.delete_all(&1, name, queryable_or_fun, opts))
  end

  @doc """
  Causes the Multi to fail with the given value.

  Running the Multi in a transaction will execute
  no previous steps and return the value of the first
  error added.
  """
  @spec error(t(), Ecto.Multi.name(), error :: term()) :: t()
  def error(%__MODULE__{} = multi, name, value) do
    update_in(multi.multi, &Ecto.Multi.error(&1, name, value))
  end

  @doc """
  Checks if an entry matching the given query exists and stores a boolean in the Multi.

  The `name` must be unique within the Multi.

  The remaining arguments and options are the same as in `c:Ecto.Repo.exists?/2`.

  ## Example

      Multi.new()
      |> Multi.exists?(:post, Post)
      |> Multi.transact()

      Multi.new()
      |> Multi.exists?(:post, fn _changes -> Post end)
      |> Multi.transact()

  """
  @spec exists?(
          t(),
          Ecto.Multi.name(),
          queryable :: Ecto.Queryable.t() | (Ecto.Multi.changes() -> Ecto.Queryable.t()),
          opts :: Keyword.t()
        ) :: t()
  def exists?(%__MODULE__{} = multi, name, queryable_or_fun, opts \\ []) do
    update_in(multi.multi, &Ecto.Multi.exists?(&1, name, queryable_or_fun, opts))
  end

  @doc """
  Adds an insert operation to the Multi.

  The `name` must be unique within the Multi.

  The remaining arguments and options are the same as in `c:Ecto.Repo.insert/2`.

  ## Example

      Multi.new()
      |> Multi.insert(:insert, %Post{title: "first"})
      |> Multi.transact()

      Multi.new()
      |> Multi.insert(:post, %Post{title: "first"})
      |> Multi.insert(:comment, fn %{post: post} ->
        Ecto.build_assoc(post, :comments)
      end)
      |> Multi.transact()

  """
  @spec insert(
          t(),
          Ecto.Multi.name(),
          Ecto.Changeset.t()
          | Ecto.Schema.t()
          | (Ecto.Multi.changes() -> Ecto.Changeset.t() | Ecto.Schema.t()),
          Keyword.t()
        ) :: t
  def insert(%__MODULE__{} = multi, name, changeset_or_struct_or_fun, opts \\ []) do
    update_in(multi.multi, &Ecto.Multi.insert(&1, name, changeset_or_struct_or_fun, opts))
  end

  @doc """
  Adds an `insert_all` operation to the Multi.

  Accepts the same arguments and options as `c:Ecto.Repo.insert_all/3`.

  ## Example

      posts = [%{title: "My first post"}, %{title: "My second post"}]
      Multi.new()
      |> Multi.insert_all(:insert_all, Post, posts)
      |> Multi.transact()

      Multi.new()
      |> Multi.run(:post, fn repo, _changes ->
        case repo.get(Post, 1) do
          nil -> {:error, :not_found}
          post -> {:ok, post}
        end
      end)
      |> Multi.insert_all(:insert_all, Comment, fn %{post: post} ->
        # Others validations

        entries
        |> Enum.map(fn comment ->
          Map.put(comment, :post_id, post.id)
        end)
      end)
      |> Multi.transact()

  """
  @spec insert_all(
          t(),
          Ecto.Multi.name(),
          term(),
          entries_or_query_or_fun ::
            [map() | Keyword.t()]
            | (Ecto.Multi.changes() -> [map() | Keyword.t()])
            | Ecto.Query.t(),
          Keyword.t()
        ) :: t
  def insert_all(
        %__MODULE__{} = multi,
        name,
        schema_or_source,
        entries_or_query_or_fun,
        opts \\ []
      ) do
    update_in(
      multi.multi,
      &Ecto.Multi.insert_all(&1, name, schema_or_source, entries_or_query_or_fun, opts)
    )
  end

  @doc """
  Inserts or updates a changeset depending on whether or not the changeset was persisted.

  The `name` must be unique within the Multi.

  The remaining arguments and options are the same as in `c:Ecto.Repo.insert_or_update/2`.

  ## Example

      changeset = Post.changeset(%Post{}, %{title: "New title"})
      Multi.new()
      |> Multi.insert_or_update(:insert_or_update, changeset)
      |> Multi.transact()

      Multi.new()
      |> Multi.run(:post, fn repo, _changes ->
        {:ok, repo.get(Post, 1) || %Post{}}
      end)
      |> Multi.insert_or_update(:update, fn %{post: post} ->
        Ecto.Changeset.change(post, title: "New title")
      end)
      |> Multi.transact()

  """
  @spec insert_or_update(
          t(),
          Ecto.Multi.name(),
          Ecto.Changeset.t() | (Ecto.Multi.changes() -> Ecto.Changeset.t()),
          Keyword.t()
        ) :: t()
  def insert_or_update(%__MODULE__{} = multi, name, changeset_or_fun, opts \\ []) do
    update_in(multi.multi, &Ecto.Multi.insert_or_update(&1, name, changeset_or_fun, opts))
  end

  @doc """
  Merges a Multi returned dynamically by an anonymous function.

  This function is useful when the Multi to be merged requires information
  from the original Multi. The second argument is an anonymous function
  that receives the Multi changes so far. The anonymous function must return
  another Multi.

  If you would prefer to simply merge two Multis together, see `append/2` or
  `prepend/2`.

  Duplicated operations are not allowed.

  ## Example

      multi =
        Multi.new()
        |> Multi.insert(:post, %Post{title: "first"})

      multi
      |> Multi.merge(fn %{post: post} ->
        Multi.new()
        |> Multi.insert(:comment, Ecto.build_assoc(post, :comments))
      end)
      |> Multi.transact()

  """
  @spec merge(t(), (Ecto.Multi.changes() -> t())) :: t()
  def merge(%__MODULE__{} = multi, merge) when is_function(merge, 1) do
    update_in(multi.multi, &Ecto.Multi.merge(&1, fn changes -> merge.(changes).multi end))
  end

  @doc """
  Inspects results from a Multi.

  By default, the name is shown as a label to the inspect. Custom labels are
  supported through the `IO.inspect/2` `label` option.

  ## Options

  All options for IO.inspect/2 are supported, as well as:

    * `:only` - A field or a list of fields to inspect, will print the entire
      map by default.

  ## Examples

      Multi.new()
      |> Multi.insert(:person_a, changeset)
      |> Multi.insert(:person_b, changeset)
      |> Multi.inspect()
      |> Multi.transact()

  Prints:
      %{person_a: %Person{...}, person_b: %Person{...}}

  We can use the `:only` option to limit which fields will be printed:

      Multi.new()
      |> Multi.insert(:person_a, changeset)
      |> Multi.insert(:person_b, changeset)
      |> Multi.inspect(only: :person_a)
      |> Multi.transact()

  Prints:
      %{person_a: %Person{...}}

  """
  @spec inspect(t(), Keyword.t()) :: t()
  def inspect(%__MODULE__{} = multi, opts \\ []) do
    update_in(multi.multi, &Ecto.Multi.inspect(&1, opts))
  end

  @doc """
  Returns an empty `Multi` struct.

  ## Example

      iex> Multi.new() |> Multi.to_list()
      []

  """
  @spec new() :: t()
  def new do
    %__MODULE__{multi: Ecto.Multi.new()}
  end

  @doc """
  Runs a query expecting one result and stores the result in the Multi.

  The `name` must be unique within the Multi.

  The remaining arguments and options are the same as in `c:Ecto.Repo.one/2`.

  ## Example

      Multi.new()
      |> Multi.one(:post, Post)
      |> Multi.one(:author, fn %{post: post} ->
        from(a in Author, where: a.id == ^post.author_id)
      end)
      |> Multi.transact()

  """
  @spec one(
          t(),
          Ecto.Multi.name(),
          queryable :: Ecto.Queryable.t() | (Ecto.Multi.changes() -> Ecto.Queryable.t()),
          opts :: Keyword.t()
        ) :: t()
  def one(%__MODULE__{} = multi, name, queryable_or_fun, opts \\ []) do
    update_in(multi.multi, &Ecto.Multi.one(&1, name, queryable_or_fun, opts))
  end

  @doc """
  Adds a value to the changes so far under the given name.

  The given `value` is added to the Multi before the transaction starts.
  If you would like to run arbitrary functions as part of your transaction,
  see `run/3` or `run/5`.

  ## Example

  Imagine there is an existing company schema that you retrieved from
  the database. You can insert it as a change in the Multi using `put/3`:

      Multi.new()
      |> Multi.put(:company, company)
      |> Multi.insert(:user, fn changes -> User.changeset(changes.company) end)
      |> Multi.insert(:person, fn changes -> Person.changeset(changes.user, changes.company) end)
      |> Multi.transact()

  In the example above, there isn't a significant benefit in putting
  the `company` in the Multi because you could also access the
  `company` variable directly inside the anonymous function.

  However, the benefit of `put/3` is seen when composing `Ecto.Multi`s.
  If the insert operations above were defined in another module,
  you could use `put(:company, company)` to inject changes that
  will be accessed by other functions down the chain, removing
  the need to pass both `multi` and `company` values around.
  """
  @spec put(t(), Ecto.Multi.name(), any()) :: t()
  def put(%__MODULE__{} = multi, name, value) do
    update_in(multi.multi, &Ecto.Multi.put(&1, name, value))
  end

  @doc """
  Adds a function to run as part of the Multi.

  The function should return either `{:ok, value}` or `{:error, value}`,
  and receives the repo as the first argument and the changes so far
  as the second argument.

  ## Example

      Multi.run(multi, :write, fn _repo, %{image: image} ->
        with :ok <- File.write(image.name, image.contents) do
          {:ok, nil}
        end
      end)

  """
  @spec run(t(), Ecto.Multi.name(), Ecto.Multi.run()) :: t()
  def run(%__MODULE__{} = multi, name, run) when is_function(run, 2) do
    update_in(multi.multi, &Ecto.Multi.run(&1, name, run))
  end

  @doc """
  Returns the list of operations stored in the Multi.

  Always use this function when you need to access the operations you
  have defined in `Multi`. Inspecting the `Multi` struct internals
  directly is discouraged.
  """
  @spec to_list(t()) :: [{Ecto.Multi.name(), term()}]
  def to_list(%__MODULE__{} = multi) do
    Ecto.Multi.to_list(multi.multi)
  end

  @doc """
  Adds an update operation to the Multi.

  The `name` must be unique within the Multi.

  The remaining arguments and options are the same as in `c:Ecto.Repo.update/2`.

  ## Example

      post = MyApp.Repo.get!(Post, 1)
      changeset = Ecto.Changeset.change(post, title: "New title")
      Multi.new()
      |> Multi.update(:update, changeset)
      |> Multi.transact()

      Multi.new()
      |> Multi.insert(:post, %Post{title: "first"})
      |> Multi.update(:fun, fn %{post: post} ->
        Ecto.Changeset.change(post, title: "New title")
      end)
      |> Multi.transact()

  """
  @spec update(
          t(),
          Ecto.Multi.name(),
          Ecto.Changeset.t() | (Ecto.Multi.changes() -> Ecto.Changeset.t()),
          Keyword.t()
        ) :: t()
  def update(%__MODULE__{} = multi, name, changeset_or_fun, opts \\ []) do
    update_in(multi.multi, &Ecto.Multi.update(&1, name, changeset_or_fun, opts))
  end

  @doc """
  Adds an `update_all` operation to the Multi.

  Accepts the same arguments and options as `c:Ecto.Repo.update_all/3`.

  ## Example

      Multi.new()
      |> Multi.update_all(:update_all, Post, set: [title: "New title"])
      |> Multi.transact()

      Multi.new()
      |> Multi.run(:post, fn repo, _changes ->
        case repo.get(Post, 1) do
          nil -> {:error, :not_found}
          post -> {:ok, post}
        end
      end)
      |> Multi.update_all(:update_all, fn %{post: post} ->
        # Others validations
        from(c in Comment, where: c.post_id == ^post.id, update: [set: [title: "New title"]])
      end, [])
      |> Multi.transact()

  """
  @spec update_all(
          t(),
          Ecto.Multi.name(),
          Ecto.Queryable.t() | (Ecto.Multi.changes() -> Ecto.Queryable.t()),
          Keyword.t(),
          Keyword.t()
        ) :: t
  def update_all(%__MODULE__{} = multi, name, queryable_or_fun, updates, opts \\ []) do
    update_in(multi.multi, &Ecto.Multi.update_all(&1, name, queryable_or_fun, updates, opts))
  end

  @doc ~S"""
  Acquires a transaction-scoped advisory lock for the application-defined key.

  This is useful when there would otherwise be nothing to lock.

  ## Example

      Multi.new()
      |> Multi.lock_advisory(:lock_user_ip, "ip:#{ip}")
      |> Multi.transact()

  """
  @spec lock_advisory(t(), Ecto.Multi.name(), binary()) :: t()
  def lock_advisory(%__MODULE__{} = multi, name, key) do
    lock_fn =
      fn repo, _changes ->
        repo.query("SELECT pg_advisory_xact_lock(hashtextextended($1::text, 0))", [key])
      end

    update_in(multi.multi, &Ecto.Multi.run(&1, name, lock_fn))
  end

  @doc """
  Locks all of the rows returned by the query for update.

  The locked result is available under `name` to later Multi steps. This is
  useful before making a change that depends on the returned rows' current
  state. The query may be a function of earlier Multi changes and is evaluated
  inside the transaction.

  > #### Warning {: .warning}
  >
  > In PostgreSQL, rows are locked in the order of the `ORDER BY` clause as rows
  > were when the table was scanned. To avoid deadlocks when using `lock_all/3`,
  > you must provide a query with a fully deterministic ordering, on a column
  > that never changes for a given row, such as a surrogate `id` key.

  ## Example

      query = Image |> where([i], i.id in ^image_ids) |> order_by(asc: :id)

      Multi.new()
      |> Multi.lock_all(:user, query)
      |> Multi.transact()

  """
  @spec lock_all(
          t(),
          Ecto.Multi.name(),
          Ecto.Queryable.t() | (Ecto.Multi.changes() -> Ecto.Queryable.t())
        ) :: t()
  def lock_all(%__MODULE__{} = multi, name, queryable_or_fun) do
    lock_fn =
      fn repo, changes ->
        queryable =
          if is_function(queryable_or_fun, 1) do
            queryable_or_fun.(changes)
          else
            queryable_or_fun
          end

        {:ok,
         queryable
         |> lock("FOR UPDATE")
         |> repo.all()}
      end

    update_in(multi.multi, &Ecto.Multi.run(&1, name, lock_fn))
  end

  @doc """
  Locks a query result for update, or aborts the transaction if it was not found.

  The locked result is available under `name` to later Multi steps. This is
  useful before making a change that depends on the row's current state. The
  query may be a function of earlier Multi changes and is evaluated inside the
  transaction.

  ## Example

      Multi.new()
      |> Multi.lock_one(:user, from(u in User, where: u.id == ^user_id))
      |> Multi.transact()

      Multi.new()
      |> Multi.lock_one(:topic, topic_query)
      |> Multi.lock_one(:forum, fn %{topic: topic} ->
        from(forum in Forum, where: forum.id == ^topic.forum_id)
      end)
      |> Multi.transact()

  """
  @spec lock_one(
          t(),
          Ecto.Multi.name(),
          Ecto.Queryable.t() | (Ecto.Multi.changes() -> Ecto.Queryable.t())
        ) :: t()
  def lock_one(%__MODULE__{} = multi, name, queryable_or_fun) do
    lock_fn =
      fn repo, changes ->
        queryable =
          if is_function(queryable_or_fun, 1) do
            queryable_or_fun.(changes)
          else
            queryable_or_fun
          end

        queryable
        |> lock("FOR UPDATE")
        |> repo.one()
        |> case do
          nil -> {:error, :not_found}
          result -> {:ok, result}
        end
      end

    update_in(multi.multi, &Ecto.Multi.run(&1, name, lock_fn))
  end

  @doc """
  Run the Multi steps inside a transaction.

  Allows setting the transaction isolation level to SERIALIZABLE if
  `isolation: :serializable` is provided in `opts`.

  See `c:Ecto.Repo.transact/2` for more information about options.
  """
  @spec transact(t(), Keyword.t()) :: {:ok, Ecto.Multi.changes()} | Ecto.Multi.failure()
  def transact(%__MODULE__{} = multi, opts \\ []) do
    {isolation, opts} = Keyword.pop(opts, :isolation)

    multi =
      case isolation do
        nil ->
          multi

        :serializable ->
          new()
          |> run(:set_isolation, fn repo, _ ->
            repo.query("SET TRANSACTION ISOLATION LEVEL SERIALIZABLE")
          end)
          |> append(multi)
      end

    multi.multi
    |> Philomena.Repo.transact(opts)
    |> case do
      {:ok, changes} ->
        :ok =
          changes
          |> Enum.each(fn
            {{:on_commit, _ref}, callback} ->
              callback.(changes)

            _ ->
              :ok
          end)

        {:ok, changes}

      {:error, _step, _reason, changes} = error ->
        changes
        |> Enum.each(fn
          {{:on_rollback, _ref}, callback} ->
            callback.(changes)

          _ ->
            :ok
        end)

        error

      error ->
        error
    end
  end

  @doc """
  Run the Multi steps inside a transaction, restarting the transaction while
  any step returns `{:error, :conflict}`, or if the database reports a
  serialization failure.

  See `transact/2` for more information.
  """
  @spec transact_with_automatic_retry(t(), Keyword.t()) ::
          {:ok, Ecto.Multi.changes()} | Ecto.Multi.failure()
  def transact_with_automatic_retry(%__MODULE__{} = multi, opts \\ []) do
    try do
      multi
      |> transact(opts)
      |> case do
        {:ok, changes} ->
          {:ok, changes}

        {:error, _step, :conflict, _changes} ->
          transact_with_automatic_retry(multi, opts)

        error ->
          error
      end
    rescue
      error in Postgrex.Error ->
        case error.postgres do
          %{code: :serialization_failure} ->
            transact_with_automatic_retry(multi, opts)

          _postgres ->
            reraise error, __STACKTRACE__
        end
    end
  end

  @doc """
  Registers a callback to occur after the Multi commits.

  The callback receives the transaction changes and runs only after a
  successful transaction. There is no ordering guarantee of post-commit
  callback execution. Use this for side effects that must occur after
  transaction completion, like object storage or indexing.

  ## Example

      Multi.new()
      |> Multi.run(:user, fn _repo, _changes -> {:ok, user} end)
      |> Multi.on_commit(fn %{user: user} -> Users.reindex_user(user) end)
      |> Multi.transact()

  """
  @spec on_commit(t(), (Ecto.Multi.changes() -> any())) :: t()
  def on_commit(%__MODULE__{} = multi, callback) when is_function(callback, 1) do
    update_in(multi.multi, &Ecto.Multi.put(&1, {:on_commit, make_ref()}, callback))
  end

  @doc """
  Registers a callback to occur when the Multi transaction rolls back.

  The callback receives the changes from the failed transaction. This is useful
  for compensating external reservations made by a `Multi.run/3` step.
  """
  @spec on_rollback(t(), (Ecto.Multi.changes() -> any())) :: t()
  def on_rollback(%__MODULE__{} = multi, callback) when is_function(callback, 1) do
    update_in(multi.multi, &Ecto.Multi.put(&1, {:on_rollback, make_ref()}, callback))
  end

  @doc """
  Reserves an external action for the transaction and releases it if the
  transaction rolls back.

  `record_action` must return `:ok` or an error tuple. The reservation is
  stored as `:action_reservation` in the Multi changes.
  """
  @spec reserve_action(t(), (-> :ok | {:error, term()}), (-> :ok)) :: t()
  def reserve_action(%__MODULE__{} = multi, record_action, rollback_action)
      when is_function(record_action, 0) and is_function(rollback_action, 0) do
    multi
    |> run(:action_reservation, fn _repo, _changes ->
      case record_action.() do
        :ok -> {:ok, nil}
        error -> error
      end
    end)
    |> on_rollback(fn changes ->
      if Map.has_key?(changes, :action_reservation) do
        rollback_action.()
      end

      :ok
    end)
  end
end
