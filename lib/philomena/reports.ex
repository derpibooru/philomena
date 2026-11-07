defmodule Philomena.Reports do
  @moduledoc """
  Report forms, submission limits, staff review, and report search indexing.
  """

  import Ecto.Query, warn: false

  import Philomena.Authorization,
    only: [authorize: 3, verify_not_banned: 1, verify_write_access: 1]

  alias Philomena.Multi
  alias Philomena.Attribution.Actor
  alias Philomena.Comments
  alias Philomena.Comments.Comment
  alias Philomena.Commissions
  alias Philomena.Commissions.Commission
  alias Philomena.Conversations
  alias Philomena.Conversations.Conversation
  alias Philomena.Galleries
  alias Philomena.Galleries.Gallery
  alias Philomena.Images
  alias Philomena.Images.Image
  alias Philomena.IndexWorker
  alias Philomena.Loader
  alias Philomena.ModerationLogs
  alias Philomena.ModerationLogs.Paths
  alias Philomena.ModNotes
  alias Philomena.Posts
  alias Philomena.Posts.Post
  alias Philomena.Repo
  alias Philomena.Reports
  alias Philomena.Reports.QueryBuilder
  alias Philomena.Reports.QueryForm
  alias Philomena.Reports.Report
  alias Philomena.Reports.ReportForm
  alias Philomena.Reports.ReportPage
  alias Philomena.Rules
  alias Philomena.Rules.Rule
  alias Philomena.Users
  alias Philomena.Users.User
  alias PhilomenaQuery.Batch

  alias PhilomenaQuery.Search

  @max_open_reports 5
  @default_preloads [:admin, :rule, user: :linked_tags]
  # The show page renders the reporter's badges next to their name.
  @show_preloads [:admin, :rule, user: [:linked_tags, awards: :badge]]

  @typedoc "Locator for a reportable item."
  @type target_locator ::
          {:image, Loader.integer_id()}
          | {:comment, Loader.integer_id(), Loader.integer_id()}
          | {:post, String.t(), String.t(), Loader.integer_id()}
          | {:user, String.t()}
          | {:commission, String.t()}
          | {:conversation, String.t()}
          | {:gallery, Loader.integer_id()}

  defp report_query(preloads) do
    Report
    |> preload(^preloads)
    |> preload(^Report.target_preloads())
  end

  defp load_report_target(%Actor{} = actor, locator) do
    case locator do
      {:image, image_id} ->
        Images.load_report_target(actor, image_id)

      {:comment, image_id, comment_id} ->
        Comments.load_report_target(actor, image_id, comment_id)

      {:post, forum_slug, topic_slug, post_id} ->
        Posts.load_report_target(actor, forum_slug, topic_slug, post_id)

      {:user, slug} ->
        Users.load_report_target(actor, slug)

      {:commission, slug} ->
        Commissions.load_report_target(actor, slug)

      {:conversation, slug} ->
        Conversations.load_report_target(actor, slug)

      {:gallery, gallery_id} ->
        Galleries.load_report_target(actor, gallery_id)
    end
  end

  defp open_report_count(repo, query) do
    query
    |> where([report], report.state in ["open", "in_progress"])
    |> repo.aggregate(:count)
  end

  defp ensure_report_limit(repo, %Actor{user: user, ip: ip} = actor) do
    cond do
      authorize(actor, :bypass_submission_limit, Report) == :ok ->
        :ok

      not is_nil(user) and
          open_report_count(repo, where(Report, user_id: ^user.id)) >= @max_open_reports ->
        {:error, :too_many_reports}

      open_report_count(repo, where(Report, ip: ^ip)) >= @max_open_reports ->
        {:error, :too_many_reports}

      true ->
        :ok
    end
  end

  defp put_lock_report(%Multi{} = multi, %Actor{} = actor, action, report_id) do
    multi
    |> Multi.lock_one(:locked_report, where(Report, id: ^report_id))
    |> Multi.run(:authorize, fn _repo, %{locked_report: report} ->
      with :ok <- authorize(actor, action, report) do
        {:ok, nil}
      end
    end)
  end

  defp map_lock_errors(result) do
    case result do
      {:error, _step, :unauthorized, _changes} ->
        {:error, :unauthorized}

      {:error, _step, :not_found, _changes} ->
        {:error, :not_found}
    end
  end

  defp close_report_query(%User{id: user_id}, [{column, id}])
       when column in [
              :image_id,
              :comment_id,
              :post_id,
              :reported_user_id,
              :commission_id,
              :conversation_id,
              :gallery_id
            ] do
    now = DateTime.utc_now(:second)

    from report in Report,
      where: field(report, ^column) == ^id and report.open == true,
      select: report.id,
      update: [
        set: [open: false, state: "closed", admin_id: ^user_id, updated_at: ^now]
      ]
  end

  @doc """
  Enqueues a search reindex of the reports with the given ids.

  ## Examples

      iex> reindex_reports([1, 2])
      :ok

  """
  @spec reindex_reports([integer()]) :: :ok
  def reindex_reports([]), do: :ok

  def reindex_reports(report_ids) do
    Exq.enqueue(Exq, "indexing", IndexWorker, ["Reports", "id", report_ids])
    :ok
  end

  defp put_reindex_report(%Multi{} = multi, report_step \\ :report) do
    Multi.on_commit(multi, fn %{^report_step => report} ->
      Exq.enqueue(Exq, "indexing", IndexWorker, ["Reports", "id", [report.id]])
    end)
  end

  @doc """
  Returns the maximum number of open reports allowed for a regular submitter.

  ## Examples

      iex> max_open_reports()
      5

  """
  @spec max_open_reports() :: pos_integer()
  def max_open_reports, do: @max_open_reports

  @doc """
  Returns the number of open reports visible in the staff counter.

  The count is authorized with `:index` on `Report`. Unauthorized users
  receive `nil`.

  ## Examples

      iex> count_open_reports(moderator)
      4

      iex> count_open_reports(user)
      nil

  """
  @spec count_open_reports(Actor.t()) :: non_neg_integer() | nil
  def count_open_reports(%Actor{} = actor) do
    case authorize(actor, :index, Report) do
      :ok ->
        Report
        |> where(open: true)
        |> Repo.aggregate(:count)

      {:error, :unauthorized} ->
        nil
    end
  end

  @doc """
  Loads the signed-in actor's reports, newest first.

  Results are scoped to `actor.user`. Anonymous actors are unauthorized.

  ## Examples

      iex> list_user_reports(actor, pagination)
      {:ok, %Scrivener.Page{}}

      iex> list_user_reports(anonymous, pagination)
      {:error, :unauthorized}

  """
  @spec list_user_reports(Actor.t(), Repo.pagination_params()) ::
          {:ok, Scrivener.Page.t(Report.t())} | {:error, :unauthorized}
  def list_user_reports(%Actor{user: user} = actor, pagination) do
    with :ok <- authorize(actor, :index_own, Report) do
      reports =
        Report
        |> where(user_id: ^user.id)
        |> order_by(desc: :created_at)
        |> preload(:rule)
        |> preload(^Report.target_preloads())
        |> Repo.paginate(pagination)

      {:ok, reports}
    end
  end

  @doc """
  Loads the staff report index described by `params` and `pagination`.

  Access is authorized with `:index` before any report query runs. A `query`
  parameter selects the report search language. Malformed search text returns
  `{:error, changeset}` with the error rendered in the query form.

  ## Examples

      iex> list_reports(admin, %{"query" => "open:true"}, pagination)
      {:ok, %ReportPage{}, %Ecto.Changeset{}}

      iex> list_reports(user, %{}, pagination)
      {:error, :unauthorized}

  """
  @spec list_reports(Actor.t(), map(), Repo.pagination_params()) ::
          {:ok, ReportPage.t(), Ecto.Changeset.t()}
          | {:error, Ecto.Changeset.t()}
          | {:error, :unauthorized}
  def list_reports(%Actor{user: user} = actor, params, pagination) do
    with :ok <- authorize(actor, :index, Report),
         {:ok, query, query_form} <- QueryBuilder.build_query(params, user) do
      reports =
        Report
        |> Search.search_definition(query, pagination)
        |> Search.search_records(report_query(@default_preloads))

      {my_reports, system_reports} =
        if not is_nil(query_form.query) do
          {[], []}
        else
          open_report_query =
            Report
            |> where(open: true)
            |> preload(^@default_preloads)
            |> preload(^Report.target_preloads())
            |> order_by(desc: :created_at)

          my_reports = where(open_report_query, admin_id: ^user.id)
          system_reports = where(open_report_query, system: true)

          {Repo.all(my_reports), Repo.all(system_reports)}
        end

      page =
        %ReportPage{
          reports: reports,
          my_reports: my_reports,
          system_reports: system_reports
        }

      {:ok, page, QueryForm.changeset(query_form, user.id)}
    end
  end

  @doc """
  Loads a report for the staff show page with its target associations resolved.

  Malformed and missing IDs are always not-found. A real report the actor may
  not show is unauthorized.

  ## Examples

      iex> show_report(moderator, "1")
      {:ok, %Report{}}

      iex> show_report(moderator, "999999999")
      {:error, :not_found}

  """
  @spec show_report(Actor.t(), Loader.integer_id()) ::
          {:ok, Report.t()} | {:error, :unauthorized | :not_found}
  def show_report(%Actor{} = actor, id) do
    Loader.fetch_and_authorize(report_query(@show_preloads), actor, :show, id)
  end

  @doc """
  Returns rendered moderator notes attached to `report`, or `nil` when the actor
  may not read them.

  The note context separately authorizes the report with `:show_mod_notes`, so
  sensitive note queries do not run before that gate.

  ## Examples

      iex> mod_notes(moderator, report, renderer)
      [{%ModNote{}, "rendered"}]

      iex> mod_notes(user, report, renderer)
      nil

  """
  @spec mod_notes(Actor.t(), Report.t(), (list() -> list())) :: list() | nil
  def mod_notes(%Actor{} = actor, %Report{} = report, collection_renderer) do
    case ModNotes.list_for_target(actor, {:report, report.id}, collection_renderer) do
      {:ok, notes} -> notes
      {:error, _reason} -> nil
    end
  end

  @doc """
  Builds a report form for the target described by `locator`.

  A ban is checked before the owning context safely loads and authorizes the
  target; a missing fingerprint is left to `create_report/3`. The returned `ReportForm` retains both the target and its empty
  report changeset. Malformed and missing locators are not-found for every
  actor. Hidden or otherwise forbidden real targets are unauthorized.

  ## Examples

      iex> new_report(actor, {:image, "1"})
      {:ok, %ReportForm{target: %Image{}}}

      iex> new_report(banned_actor, {:image, "1"})
      {:error, :ban}

  """
  @spec new_report(Actor.t(), target_locator()) ::
          {:ok, ReportForm.t()} | {:error, :ban | :unauthorized | :not_found}
  def new_report(%Actor{} = actor, locator) do
    with :ok <- verify_not_banned(actor),
         {:ok, target} <- load_report_target(actor, locator) do
      changeset =
        target
        |> Ecto.build_assoc(:reports)
        |> Report.changeset()

      {:ok,
       %ReportForm{
         target: target,
         changeset: changeset,
         rules: Rules.list_reportable_rules()
       }}
    end
  end

  @doc """
  Creates a report for the safely loaded target described by `locator`.

  The same loading and visibility checks as `new_report/2` run, after full write
  access is verified.
  Normal and anonymous users are subject to an open report limit; staff are
  exempt. A rejected insert returns a `ReportForm` carrying the loaded target
  and rejected changeset, while a successful insert queues the report for
  search indexing.

  ## Examples

      iex> create_report(actor, {:image, "1"}, %{"reason" => "Spam"})
      {:ok, %Report{}}

      iex> create_report(actor, {:image, "1"}, %{"reason" => ""})
      {:error, %ReportForm{changeset: %Ecto.Changeset{}}}

      iex> create_report(actor, {:image, "1"}, attrs)
      {:error, :too_many_reports}

  """
  @spec create_report(Actor.t(), target_locator(), map() | nil) ::
          {:ok, Report.t()}
          | {:error, :too_many_reports | :ban | :unauthorized | :not_found}
          | {:error, ReportForm.t()}
  def create_report(%Actor{user: user} = actor, locator, params) do
    with :ok <- verify_write_access(actor),
         {:ok, target} <- load_report_target(actor, locator),
         {:ok, rule_id} <- Report.fetch_rule_id(params),
         {:ok, rule} <- Rules.fetch_rule(rule_id) do
      report_changeset =
        target
        |> Ecto.build_assoc(:reports)
        |> Report.user_creation_changeset(params, actor, rule)

      Multi.new()
      |> Multi.lock_advisory(:report_limit_ip, "reports:ip:#{actor.ip}")
      |> then(fn multi ->
        if user do
          Multi.lock_one(multi, :report_limit_user, where(User, id: ^user.id))
        else
          multi
        end
      end)
      |> Multi.run(:report_limit, fn repo, _changes ->
        case ensure_report_limit(repo, actor) do
          :ok -> {:ok, nil}
          error -> error
        end
      end)
      |> Multi.insert(:report, report_changeset)
      |> put_reindex_report()
      |> Multi.transact()
      |> case do
        {:ok, %{report: %Report{} = report}} ->
          {:ok, report}

        {:error, :report, %Ecto.Changeset{} = changeset, _changes} ->
          {:error,
           %ReportForm{
             target: target,
             changeset: changeset,
             rules: Rules.list_reportable_rules()
           }}

        {:error, :report_limit, :too_many_reports, _changes} ->
          {:error, :too_many_reports}
      end
    end
  end

  @doc """
  Claims an open, unclaimed report for the acting staff member.

  The report is loaded under a row lock and authorized with `:claim`. A raced
  or repeated claim returns a changeset error rather than reassigning the
  report.

  ## Examples

      iex> create_report_claim(moderator, "1")
      {:ok, %Report{state: "in_progress"}}

      iex> create_report_claim(user, "1")
      {:error, :unauthorized}

  """
  @spec create_report_claim(Actor.t(), Loader.integer_id()) ::
          {:ok, Report.t()} | {:error, :not_found | :unauthorized | Ecto.Changeset.t()}
  def create_report_claim(%Actor{user: user} = actor, report_id) do
    with {:ok, report_id} <- Loader.parse_id(report_id) do
      Multi.new()
      |> put_lock_report(actor, :claim, report_id)
      |> Multi.update(:report, fn %{locked_report: report} ->
        Report.claim_changeset(report, user)
      end)
      |> put_reindex_report()
      |> ModerationLogs.put_log(
        :moderation_log,
        actor,
        fn %{report: report} ->
          {
            "Report.Claim:create",
            Paths.admin_report_path(report.id),
            "Claimed report"
          }
        end
      )
      |> Multi.transact()
      |> case do
        {:ok, %{report: %Report{} = report}} ->
          {:ok, report}

        {:error, :report, %Ecto.Changeset{} = changeset, _changes} ->
          {:error, changeset}

        error ->
          map_lock_errors(error)
      end
    end
  end

  @doc """
  Releases the claim on an open report.

  The report is locked and authorized with `:unclaim`.

  ## Examples

      iex> delete_report_claim(moderator, "1")
      {:ok, %Report{state: "open"}}

  """
  @spec delete_report_claim(Actor.t(), Loader.integer_id()) ::
          {:ok, Report.t()} | {:error, :not_found | :unauthorized | Ecto.Changeset.t()}
  def delete_report_claim(%Actor{user: user} = actor, report_id) do
    with {:ok, report_id} <- Loader.parse_id(report_id) do
      Multi.new()
      |> put_lock_report(actor, :unclaim, report_id)
      |> Multi.update(:report, fn %{locked_report: report} ->
        Report.unclaim_changeset(report, user)
      end)
      |> put_reindex_report()
      |> ModerationLogs.put_log(
        :moderation_log,
        actor,
        fn %{report: report} ->
          {
            "Report.Claim:delete",
            Paths.admin_report_path(report.id),
            "Released report"
          }
        end
      )
      |> Multi.transact()
      |> case do
        {:ok, %{report: %Report{} = report}} ->
          {:ok, report}

        {:error, :report, %Ecto.Changeset{} = changeset, _changes} ->
          {:error, changeset}

        error ->
          map_lock_errors(error)
      end
    end
  end

  @doc """
  Closes a report on behalf of the acting staff member.

  The report is locked and authorized with `:close`.

  ## Examples

      iex> create_report_close(moderator, "1")
      {:ok, %Report{state: "closed", open: false}}

  """
  @spec create_report_close(Actor.t(), Loader.integer_id()) ::
          {:ok, Report.t()} | {:error, :not_found | :unauthorized | Ecto.Changeset.t()}
  def create_report_close(%Actor{user: user} = actor, report_id) do
    with {:ok, report_id} <- Loader.parse_id(report_id) do
      Multi.new()
      |> put_lock_report(actor, :close, report_id)
      |> Multi.update(:report, fn %{locked_report: report} ->
        Report.close_changeset(report, user)
      end)
      |> put_reindex_report()
      |> ModerationLogs.put_log(
        :moderation_log,
        actor,
        fn %{report: report} ->
          {
            "Report.Close:create",
            Paths.admin_report_path(report.id),
            "Closed report"
          }
        end
      )
      |> Multi.transact()
      |> case do
        {:ok, %{report: %Report{} = report}} ->
          {:ok, report}

        {:error, :report, %Ecto.Changeset{} = changeset, _changes} ->
          {:error, changeset}

        error ->
          map_lock_errors(error)
      end
    end
  end

  @doc """
  Adds a bulk close of reports for one already loaded target to `multi`.

  This is an internal composition API for owning contexts that delete or
  approve a reportable target.

  ## Examples

      iex> put_close_reports(multi, :reports, moderator, image_id: image.id)
      %Ecto.Multi{}

  """
  @spec put_close_reports(Multi.t(), Multi.name(), User.t(), keyword()) :: Multi.t()
  def put_close_reports(%Multi{} = multi, step, closing_user, target) do
    multi
    |> Multi.update_all(step, fn _ -> close_report_query(closing_user, target) end, [])
    |> Multi.on_commit(fn %{^step => {_count, report_ids}} ->
      reindex_reports(report_ids)
    end)
  end

  @doc """
  Creates an internal system report within the transaction described by `multi`.

  The rule name must identify a reportable rule. This trusted service is used by
  owning contexts to add a report when their target has been created or moderated.

  ## Examples

      iex> put_create_system_report(
      ...>   multi,
      ...>   "Approval",
      ...>   "Needs review",
      ...>   :comment_id,
      ...>   comment.id
      ...> )
      %Multi{}

  """
  @spec put_create_system_report(
          multi :: Multi.t(),
          rule_name :: String.t(),
          reason :: String.t(),
          target_column :: atom(),
          target_id :: integer()
        ) ::
          Multi.t()
  def put_create_system_report(multi, rule_name, reason, target_column, target_id) do
    {:ok, rule} = Rules.fetch_rule_by_name(rule_name)

    attrs = %{reason: reason, user_agent: "system"}

    actor = %Actor{
      ip: %Postgrex.INET{address: {127, 0, 0, 1}, netmask: 32},
      fingerprint: "ffff"
    }

    report_changeset =
      Report
      |> struct([{target_column, target_id}])
      |> Report.system_creation_changeset(attrs, actor, rule)

    multi
    |> Multi.insert(:report, report_changeset)
    |> put_reindex_report()
  end

  @doc """
  Converts one legacy report reason and persists the structured fields.
  """
  @spec convert_legacy_report!(Report.t(), String.t(), Rule.t()) :: Report.t()
  def convert_legacy_report!(%Report{} = report, reason, rule) do
    report
    |> Report.conversion_changeset(%{reason: String.trim(reason)}, rule)
    |> Repo.update!()
  end

  @doc """
  Replaces attribution data on a user's reports in batches.
  """
  @spec wipe_user_attribution!(integer(), term(), String.t()) :: :ok
  def wipe_user_attribution!(user_id, ip, fingerprint) do
    Report
    |> where(user_id: ^user_id)
    |> Batch.query_batches()
    |> Enum.each(&Repo.update_all(&1, set: [ip: ip, fingerprint: fingerprint]))

    :ok
  end

  @doc """
  Updates indexed user name fields.

  This maintenance callback is invoked after a committed user rename.

  ## Examples

      iex> user_name_reindex("Old Name", "New Name")
      [{:ok, %Req.Response{}}]

  """
  @spec user_name_reindex(String.t(), String.t()) :: [term()]
  def user_name_reindex(old_name, new_name) do
    data = Reports.SearchIndex.user_name_update_by_query(old_name, new_name)
    Search.update_by_query(Report, data.query, data.set_replacements, data.replacements)
  end

  @doc """
  Returns the associations required to serialize reports into OpenSearch.

  This is the batch-indexer behaviour used by `Philomena.SearchIndexer`.

  ## Examples

      iex> indexing_preloads()
      [:user, :admin, ...]

  """
  @spec indexing_preloads() :: list()
  def indexing_preloads do
    [
      :user,
      :admin,
      :reported_user,
      image: from(image in Image, preload: :user),
      comment: from(comment in Comment, preload: :user),
      post: from(post in Post, preload: :user),
      commission: from(commission in Commission, preload: :user),
      conversation: from(conversation in Conversation, preload: [:from, :to]),
      gallery: from(gallery in Gallery, preload: :user)
    ]
  end

  @doc """
  Reindexes reports matching `column` and `condition` for the index worker.

  `column` is supplied by the trusted worker registry, not request input.

  ## Examples

      iex> perform_reindex(:id, [1, 2])
      :ok

  """
  @spec perform_reindex(atom(), list()) :: :ok
  def perform_reindex(column, condition) do
    Report
    |> where([report], field(report, ^column) in ^condition)
    |> preload(^indexing_preloads())
    |> Search.reindex(Report)
  end
end
