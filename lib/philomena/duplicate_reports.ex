defmodule Philomena.DuplicateReports do
  @moduledoc """
  Duplicate-report submission, staff review, perceptual matching, and reverse
  image search.
  """

  import Ecto.Query, warn: false
  import Philomena.DuplicateReports.Power

  import Philomena.Authorization,
    only: [authorize: 3, verify_not_banned: 1, verify_write_access: 1]

  import Philomena.DuplicateReports.TransactionWorkflow

  alias Philomena.Attribution.Actor
  alias Philomena.DuplicateReports.DuplicateReport
  alias Philomena.DuplicateReports.QueryBuilder
  alias Philomena.DuplicateReports.QueryForm
  alias Philomena.DuplicateReports.SearchQuery
  alias Philomena.DuplicateReports.SearchResult
  alias Philomena.DuplicateReports.Uploader
  alias Philomena.ImageIntensities.ImageIntensity
  alias Philomena.Images
  alias Philomena.Images.Image
  alias Philomena.Loader
  alias Philomena.ModerationLogs
  alias Philomena.ModerationLogs.Paths
  alias Philomena.Multi
  alias Philomena.Repo

  @report_preloads [
    :user,
    :modifier,
    image: [:user, :sources, tags: :aliases],
    duplicate_of_image: [:user, :sources, tags: :aliases]
  ]

  defp load_report(%Actor{} = actor, action, report_id) do
    with {:ok, report} <-
           Loader.fetch_and_authorize(DuplicateReport, actor, action, report_id, @report_preloads),
         :ok <- authorize(actor, :show, report.image),
         :ok <- authorize(actor, :show, report.duplicate_of_image) do
      {:ok, report}
    end
  end

  defp visible_images_query(%Actor{} = actor) do
    if authorize(actor, :show, %Image{hidden_from_users: true}) == :ok do
      Image
    else
      where(Image, hidden_from_users: false)
    end
  end

  defp duplicate_query(image_query \\ Image, {intensities, aspect_ratio}, opts) do
    aspect_dist = Keyword.get(opts, :aspect_dist, 0.05)
    limit = Keyword.get(opts, :limit, 10)
    dist = Keyword.get(opts, :dist, 0.25) * 3

    from image in image_query,
      inner_join: intensity in ImageIntensity,
      on: intensity.image_id == image.id,
      where:
        intensity.nw >= ^(intensities.nw - dist) and
          intensity.nw <= ^(intensities.nw + dist),
      where:
        intensity.ne >= ^(intensities.ne - dist) and
          intensity.ne <= ^(intensities.ne + dist),
      where:
        intensity.sw >= ^(intensities.sw - dist) and
          intensity.sw <= ^(intensities.sw + dist),
      where:
        intensity.se >= ^(intensities.se - dist) and
          intensity.se <= ^(intensities.se + dist),
      where:
        image.image_aspect_ratio >= ^(aspect_ratio - aspect_dist) and
          image.image_aspect_ratio <= ^(aspect_ratio + aspect_dist),
      order_by: [
        asc:
          power(intensity.nw - ^intensities.nw, 2) +
            power(intensity.ne - ^intensities.ne, 2) +
            power(intensity.sw - ^intensities.sw, 2) +
            power(intensity.se - ^intensities.se, 2) +
            power(image.image_aspect_ratio - ^aspect_ratio, 2),
        asc: image.id
      ],
      limit: ^limit
  end

  defp put_reject_open_reports(%Multi{} = multi) do
    Multi.update_all(
      multi,
      :rejected_open_reports,
      fn %{locked_source_image: %{id: source_id}, locked_target_image: %{id: target_id}} ->
        from report in DuplicateReport,
          where:
            (report.image_id == ^source_id and report.duplicate_of_image_id == ^target_id) or
              (report.duplicate_of_image_id == ^source_id and report.image_id == ^target_id),
          where: report.state in ^DuplicateReport.open_states(),
          select: report.id
      end,
      set: [state: "rejected"]
    )
  end

  defp affected_reports(report, {_count, ids}) do
    DuplicateReport
    |> where([other], other.id in ^Enum.uniq([report.id | ids]))
    |> preload(^@report_preloads)
  end

  @doc """
  Loads the staff duplicate-report index described by `params`.

  Unlike regular reports, which are private to staff and submitting users,
  duplicate reports are publicly-accessible information. Access to the index is
  therefore permitted to any user.

  Blank or omitted states select open and claimed reports. Invalid state
  selections return an empty page with their rejected query changeset.

  ## Examples

      iex> list_duplicate_reports(moderator, %{"states" => ["rejected"]}, pagination)
      {:ok, %Scrivener.Page{}, %Ecto.Changeset{}}

      iex> list_duplicate_reports(user, %{}, pagination)
      {:error, :unauthorized}

  """
  @spec list_duplicate_reports(Actor.t(), map(), Repo.pagination_params()) ::
          {:ok, Scrivener.Page.t(DuplicateReport.t()), Ecto.Changeset.t()}
          | {:error, :unauthorized}
  def list_duplicate_reports(%Actor{} = actor, params, pagination) do
    with :ok <- authorize(actor, :search, DuplicateReport) do
      case QueryBuilder.build_query(params) do
        {:ok, query, query_form} ->
          query = preload(query, ^@report_preloads)

          {:ok, Repo.paginate(query, pagination), QueryForm.changeset(query_form)}

        {:error, changeset} ->
          {:ok, Repo.paginate(where(DuplicateReport, false), pagination), changeset}
      end
    end
  end

  @doc """
  Loads one duplicate report for display.

  The report is authorized with `:show`, then both associated images must also
  be visible to the actor. Missing and malformed IDs are always not-found.

  ## Examples

      iex> show_duplicate_report(actor, "42")
      {:ok, %DuplicateReport{}}

      iex> show_duplicate_report(actor, "not-an-id")
      {:error, :not_found}

  """
  @spec show_duplicate_report(Actor.t(), Loader.integer_id()) ::
          {:ok, DuplicateReport.t()} | {:error, :not_found | :unauthorized}
  def show_duplicate_report(%Actor{} = actor, report_id) do
    load_report(actor, :show, report_id)
  end

  @doc """
  Prepares the duplicate-report form for one visible image.

  The form uses the same ban and `:create` prerequisites as submission; a
  missing fingerprint is left to `create_duplicate_report/4`.
  A list of all existing reports is provided for the actor to review before
  submitting a new report.

  ## Examples

      iex> new_duplicate_report(actor, "42")
      {:ok, {%Image{}, [%DuplicateReport{}], %Ecto.Changeset{}}}

      iex> new_duplicate_report(banned_actor, "42")
      {:error, :ban}

  """
  @spec new_duplicate_report(Actor.t(), Loader.integer_id()) ::
          {:ok, {Image.t(), [DuplicateReport.t()], Ecto.Changeset.t()}}
          | {:error, :ban | :not_found | :unauthorized}
  def new_duplicate_report(%Actor{} = actor, image_id) do
    with :ok <- verify_not_banned(actor),
         :ok <- authorize(actor, :create, DuplicateReport),
         {:ok, image} <- Images.load_report_target(actor, image_id) do
      changeset =
        %DuplicateReport{image_id: image.id, image: image}
        |> DuplicateReport.creation_changeset(%{}, actor.user)

      reports =
        DuplicateReport
        |> where(
          [report],
          report.image_id == ^image.id or report.duplicate_of_image_id == ^image.id
        )
        |> order_by(desc: :created_at, desc: :id)
        |> preload(^@report_preloads)
        |> Repo.all()

      {:ok, {image, reports, changeset}}
    end
  end

  @doc """
  Creates a duplicate report between two actor-visible images.

  Write access and the class `:create` ability are checked before either image
  is loaded. The locators are parsed independently; malformed, missing, or
  forbidden images return the shared loader errors. Validation failures return
  the report changeset with both images attached.

  ## Examples

      iex> create_duplicate_report(actor, "1", "2", %{"reason" => "same image"})
      {:ok, %DuplicateReport{}}

      iex> create_duplicate_report(actor, "1", "1", %{})
      {:error, %Ecto.Changeset{}}

  """
  @spec create_duplicate_report(
          Actor.t(),
          Loader.integer_id(),
          Loader.integer_id(),
          map()
        ) ::
          {:ok, DuplicateReport.t()}
          | {:error, :ban | :not_found | :unauthorized | Ecto.Changeset.t()}
  def create_duplicate_report(%Actor{user: user} = actor, source_id, target_id, attrs) do
    with :ok <- verify_write_access(actor),
         :ok <- authorize(actor, :create, DuplicateReport),
         {:ok, source} <- Images.load_report_target(actor, source_id),
         {:ok, target} <- Images.load_report_target(actor, target_id) do
      changeset =
        %DuplicateReport{
          image_id: source.id,
          image: source,
          duplicate_of_image_id: target.id,
          duplicate_of_image: target
        }
        |> DuplicateReport.creation_changeset(attrs, user)

      Multi.new()
      |> put_lock_image_pair(actor, source.id, target.id, :show)
      |> Multi.insert(:duplicate_report, changeset)
      |> Multi.transact()
      |> case do
        {:ok, %{duplicate_report: %DuplicateReport{} = report}} ->
          {:ok, report}

        {:error, :duplicate_report, %Ecto.Changeset{} = changeset, _changes} ->
          {:error, changeset}

        error ->
          map_lock_errors(error)
      end
    end
  end

  @doc """
  Generates automated duplicate reports for one media-pipeline image.

  Up to ten visible perceptual matches are considered. Each insert is
  independent and the per-target insert results are returned to the worker.

  ## Examples

      iex> generate_reports(source_image)
      [{:ok, %DuplicateReport{}}, ...]

  """
  @spec generate_reports(Image.t()) ::
          [{:ok, DuplicateReport.t()} | {:error, Ecto.Changeset.t()}]
  def generate_reports(%Image{} = source) do
    source = Repo.preload(source, :intensity)

    {source.intensity, source.image_aspect_ratio}
    |> duplicate_query(dist: 0.2)
    |> where([image], image.id != ^source.id)
    |> Repo.all()
    |> Enum.map(fn target ->
      changeset =
        %DuplicateReport{
          image_id: source.id,
          image: source,
          duplicate_of_image_id: target.id,
          duplicate_of_image: target
        }
        |> DuplicateReport.creation_changeset(%{reason: "Automated Perceptual dedupe match"})

      Multi.new()
      |> put_lock_image_pair_without_authorization(source.id, target.id)
      |> Multi.insert(:duplicate_report, changeset)
      |> Multi.transact()
      |> case do
        {:ok, %{duplicate_report: %DuplicateReport{} = report}} ->
          {:ok, report}

        {:error, :duplicate_report, %Ecto.Changeset{} = changeset, _changes} ->
          {:error, changeset}

        error ->
          map_lock_errors(error)
      end
    end)
  end

  @doc """
  Prepares an empty reverse-image-search result for the actor.

  ## Examples

      iex> create_reverse_search(actor)
      {:ok, %SearchResult{images: nil}}

  """
  @spec create_reverse_search(Actor.t()) ::
          {:ok, SearchResult.t()} | {:error, :unauthorized}
  def create_reverse_search(%Actor{} = actor) do
    with :ok <- authorize(actor, :search, DuplicateReport) do
      {:ok,
       %SearchResult{
         images: nil,
         changeset: SearchQuery.changeset(%SearchQuery{})
       }}
    end
  end

  @doc """
  Runs a reverse image search for the uploaded image in `attrs`.

  The upload metadata, distance, and limit are validated before media analysis.
  Results exclude hidden images unless the actor may view them, and carry the
  normalized search changeset alongside the page. Invalid input returns the
  rejected changeset explicitly.

  ## Examples

      iex> create_reverse_search(actor, %{"distance" => "0.25"}, upload)
      {:ok, %SearchResult{images: %Scrivener.Page{}}}

      iex> create_reverse_search(actor, %{"distance" => "bad"}, upload)
      {:error, %Ecto.Changeset{}}

  """
  @spec create_reverse_search(Actor.t(), map(), PhilomenaMedia.Upload.t() | nil) ::
          {:ok, SearchResult.t()} | {:error, :unauthorized | Ecto.Changeset.t()}
  def create_reverse_search(%Actor{} = actor, attrs, upload) do
    with :ok <- authorize(actor, :search, DuplicateReport),
         {:ok, search_query} <-
           %SearchQuery{}
           |> SearchQuery.changeset(attrs)
           |> Uploader.analyze_upload(upload)
           |> Ecto.Changeset.apply_action(:create) do
      analysis = SearchQuery.to_analysis(search_query)
      intensities = PhilomenaMedia.Processors.intensities(analysis, search_query.uploaded_image)

      images =
        actor
        |> visible_images_query()
        |> duplicate_query(
          {intensities, search_query.image_aspect_ratio},
          dist: search_query.distance,
          aspect_dist: search_query.distance,
          limit: search_query.limit
        )
        |> preload([:user, :intensity, :sources, tags: :aliases])
        |> Repo.paginate(page_size: 50)

      {:ok,
       %SearchResult{
         images: images,
         changeset: SearchQuery.changeset(search_query)
       }}
    end
  end

  @doc """
  Accepts a duplicate report and merges its source image into its target.

  Write access, the distinct `:accept` ability, the report direction, and both
  images are checked before row-locked state is changed. The report, competing
  active reports, image merge, and moderation log commit atomically. Merge
  indexing, notifications, thumbnails, and broadcasts run after commit.
  Returns the accepted report and all affected reports with display associations
  loaded so callers can refresh both accepted and rejected rows.

  ## Examples

      iex> create_duplicate_report_accept(moderator, "42")
      {:ok, %DuplicateReport{}, [%DuplicateReport{}]}

      iex> create_duplicate_report_accept(user, "42")
      {:error, :unauthorized}

  """
  @spec create_duplicate_report_accept(Actor.t(), Loader.integer_id()) ::
          {:ok, DuplicateReport.t(), [DuplicateReport.t()]}
          | {:error, :ban | :not_found | :unauthorized | Ecto.Changeset.t()}
  def create_duplicate_report_accept(%Actor{user: user} = actor, report_id) do
    with :ok <- verify_write_access(actor),
         {:ok, report} <- load_report(actor, :accept, report_id) do
      Multi.new()
      |> put_lock_image_pair_and_report(report, actor, :show, :accept)
      |> put_reject_open_reports()
      |> Multi.update(:duplicate_report, fn %{locked_duplicate_report: duplicate_report} ->
        DuplicateReport.accept_changeset(duplicate_report, user)
      end)
      |> ModerationLogs.put_log(
        :moderation_log,
        actor,
        fn %{locked_source_image: source, locked_target_image: target} ->
          {
            "DuplicateReport.Accept:create",
            Paths.image_path(source),
            "Accepted duplicate report, merged #{source.id} into #{target.id}"
          }
        end
      )
      |> Multi.merge(fn
        %{locked_source_image: source, locked_target_image: target} ->
          Images.put_merge_image(Multi.new(), source, target, user)
      end)
      |> Multi.all(:affected_reports, fn %{rejected_open_reports: reports} ->
        affected_reports(report, reports)
      end)
      |> Multi.transact()
      |> case do
        {:ok, %{duplicate_report: duplicate_report, affected_reports: affected}} ->
          {:ok, duplicate_report, affected}

        {:error, :duplicate_report, %Ecto.Changeset{} = changeset, _changes} ->
          {:error, changeset}

        {:error, :image, %Ecto.Changeset{}, %{duplicate_report: duplicate_report}} ->
          {:error, DuplicateReport.add_image_acceptance_error(duplicate_report)}

        error ->
          map_lock_errors(error)
      end
    end
  end

  @doc """
  Accepts a duplicate report in reverse and merges its target into its source.

  The original report is rejected and a locked reverse-direction report is
  inserted or accepted in the same transaction as the image merge and audit
  log. Returns the accepted reverse report and all affected reports with display
  associations loaded. Authorization and post-commit behavior match
  `create_duplicate_report_accept/2`.

  ## Examples

      iex> create_duplicate_report_accept_reverse(moderator, "42")
      {:ok, %DuplicateReport{}, [%DuplicateReport{}, %DuplicateReport{}]}

  """
  @spec create_duplicate_report_accept_reverse(Actor.t(), Loader.integer_id()) ::
          {:ok, DuplicateReport.t(), [DuplicateReport.t()]}
          | {:error, :ban | :not_found | :unauthorized | Ecto.Changeset.t()}
  def create_duplicate_report_accept_reverse(%Actor{user: user} = actor, report_id) do
    with :ok <- verify_write_access(actor),
         {:ok, report} <- load_report(actor, :accept_reverse, report_id) do
      Multi.new()
      |> put_lock_image_pair_and_report(
        report,
        actor,
        :show,
        :accept_reverse
      )
      |> Multi.one(:existing_reverse_report, fn %{locked_duplicate_report: forward_report} ->
        from reverse_report in DuplicateReport,
          where: reverse_report.id != ^forward_report.id,
          where: reverse_report.image_id == ^forward_report.duplicate_of_image_id,
          where: reverse_report.duplicate_of_image_id == ^forward_report.image_id,
          where: reverse_report.state in ^DuplicateReport.open_states(),
          order_by: [desc: :id],
          limit: 1
      end)
      |> put_reject_open_reports()
      |> Multi.insert_or_update(:reverse_report, fn
        %{existing_reverse_report: nil, locked_duplicate_report: duplicate_report} ->
          %DuplicateReport{
            image_id: duplicate_report.duplicate_of_image_id,
            duplicate_of_image_id: duplicate_report.image_id
          }
          |> DuplicateReport.reverse_accept_changeset(user, duplicate_report.reason)

        %{existing_reverse_report: reverse_report} ->
          DuplicateReport.accept_changeset(reverse_report, user)
      end)
      |> ModerationLogs.put_log(
        :moderation_log,
        actor,
        fn %{locked_source_image: source, locked_target_image: target} ->
          {
            "DuplicateReport.AcceptReverse:create",
            Paths.image_path(target),
            "Reverse-accepted duplicate report, merged #{target.id} into #{source.id}"
          }
        end
      )
      |> Multi.merge(fn
        %{locked_source_image: source, locked_target_image: target} ->
          Images.put_merge_image(Multi.new(), target, source, user)
      end)
      |> Multi.all(:affected_reports, fn
        %{rejected_open_reports: reports, reverse_report: report} ->
          affected_reports(report, reports)
      end)
      |> Multi.transact()
      |> case do
        {:ok, %{reverse_report: reverse_report, affected_reports: affected}} ->
          {:ok, reverse_report, affected}

        {:error, :reverse_report, %Ecto.Changeset{} = changeset, _changes} ->
          {:error, changeset}

        {:error, :image, %Ecto.Changeset{}, %{reverse_report: reverse_report}} ->
          {:error, DuplicateReport.add_image_acceptance_error(reverse_report)}

        error ->
          map_lock_errors(error)
      end
    end
  end

  @doc """
  Claims one open, unclaimed duplicate report for the acting staff member.

  The report is reloaded under a row lock and authorized with `:claim`. A
  repeated or racing claim returns a changeset; the audit log commits with the
  state change.

  ## Examples

      iex> create_duplicate_report_claim(moderator, "42")
      {:ok, %DuplicateReport{state: "claimed"}}

  """
  @spec create_duplicate_report_claim(Actor.t(), Loader.integer_id()) ::
          {:ok, DuplicateReport.t()}
          | {:error, :ban | :not_found | :unauthorized | Ecto.Changeset.t()}
  def create_duplicate_report_claim(%Actor{user: user} = actor, report_id) do
    with :ok <- verify_write_access(actor),
         {:ok, report} <- load_report(actor, :claim, report_id) do
      Multi.new()
      |> put_lock_image_pair_and_report(report, actor, :show, :claim)
      |> Multi.update(:duplicate_report, fn %{locked_duplicate_report: duplicate_report} ->
        DuplicateReport.claim_changeset(duplicate_report, user)
      end)
      |> ModerationLogs.put_log(
        :moderation_log,
        actor,
        "DuplicateReport.Claim:create",
        "/duplicate_reports",
        "Claimed a duplicate report"
      )
      |> Multi.transact()
      |> case do
        {:ok, %{duplicate_report: %DuplicateReport{} = duplicate_report}} ->
          {:ok, Repo.preload(duplicate_report, @report_preloads)}

        {:error, :duplicate_report, %Ecto.Changeset{} = changeset, _steps} ->
          {:error, changeset}

        error ->
          map_lock_errors(error)
      end
    end
  end

  @doc """
  Releases one claimed duplicate report.

  The locked report is authorized with `:unclaim`. An already-open or otherwise
  non-claimed report returns a changeset and does not write an audit log.

  ## Examples

      iex> delete_duplicate_report_claim(moderator, "42")
      {:ok, %DuplicateReport{state: "open"}}

  """
  @spec delete_duplicate_report_claim(Actor.t(), Loader.integer_id()) ::
          {:ok, DuplicateReport.t()}
          | {:error, :ban | :not_found | :unauthorized | Ecto.Changeset.t()}
  def delete_duplicate_report_claim(%Actor{} = actor, report_id) do
    with :ok <- verify_write_access(actor),
         {:ok, report} <- load_report(actor, :unclaim, report_id) do
      Multi.new()
      |> put_lock_image_pair_and_report(report, actor, :show, :unclaim)
      |> Multi.update(:duplicate_report, fn %{locked_duplicate_report: duplicate_report} ->
        DuplicateReport.unclaim_changeset(duplicate_report)
      end)
      |> ModerationLogs.put_log(
        :moderation_log,
        actor,
        "DuplicateReport.Claim:delete",
        "/duplicate_reports",
        "Released a duplicate report"
      )
      |> Multi.transact()
      |> case do
        {:ok, %{duplicate_report: %DuplicateReport{} = duplicate_report}} ->
          {:ok, Repo.preload(duplicate_report, @report_preloads)}

        {:error, :duplicate_report, %Ecto.Changeset{} = changeset, _steps} ->
          {:error, changeset}

        error ->
          map_lock_errors(error)
      end
    end
  end

  @doc """
  Rejects one active duplicate report.

  The locked report is authorized with `:reject`; its state change and the
  direction-bearing moderation log commit atomically.

  ## Examples

      iex> create_duplicate_report_reject(moderator, "42")
      {:ok, %DuplicateReport{state: "rejected"}}

  """
  @spec create_duplicate_report_reject(Actor.t(), Loader.integer_id()) ::
          {:ok, DuplicateReport.t()}
          | {:error, :ban | :not_found | :unauthorized | Ecto.Changeset.t()}
  def create_duplicate_report_reject(%Actor{user: user} = actor, report_id) do
    with :ok <- verify_write_access(actor),
         {:ok, report} <- load_report(actor, :reject, report_id) do
      Multi.new()
      |> put_lock_image_pair_and_report(report, actor, :show, :reject)
      |> Multi.update(:duplicate_report, fn %{locked_duplicate_report: duplicate_report} ->
        DuplicateReport.reject_changeset(duplicate_report, user)
      end)
      |> ModerationLogs.put_log(:moderation_log, actor, fn %{duplicate_report: duplicate_report} ->
        {
          "DuplicateReport.Reject:create",
          "/duplicate_reports",
          "Rejected duplicate report (#{duplicate_report.image_id} -> #{duplicate_report.duplicate_of_image_id})"
        }
      end)
      |> Multi.transact()
      |> case do
        {:ok, %{duplicate_report: %DuplicateReport{} = duplicate_report}} ->
          {:ok, Repo.preload(duplicate_report, @report_preloads)}

        {:error, :duplicate_report, %Ecto.Changeset{} = changeset, _steps} ->
          {:error, changeset}

        error ->
          map_lock_errors(error)
      end
    end
  end

  @doc """
  Rejects open duplicate reports involving `image_id` inside `multi`.

  Images composes this step when hiding an image. The DuplicateReports context
  owns the report state update and keeps it coupled to the image transaction.
  """
  @spec put_reject_image_reports(Multi.t(), Multi.name(), integer()) :: Multi.t()
  def put_reject_image_reports(%Multi{} = multi, step, image_id) do
    query =
      DuplicateReport
      |> where(state: "open")
      |> where(
        [report],
        report.image_id == ^image_id or report.duplicate_of_image_id == ^image_id
      )

    Multi.update_all(multi, step, query, set: [state: "rejected"])
  end

  @doc """
  Counts open duplicate reports for the staff navigation counter.

  The count is authorized with `:index`; unauthorized actors receive `nil`.

  ## Examples

      iex> count_duplicate_reports(moderator)
      4

      iex> count_duplicate_reports(user)
      nil

  """
  @spec count_duplicate_reports(Actor.t()) :: non_neg_integer() | nil
  def count_duplicate_reports(%Actor{} = actor) do
    case authorize(actor, :index, DuplicateReport) do
      :ok ->
        DuplicateReport
        |> where(state: "open")
        |> Repo.aggregate(:count)

      _error ->
        nil
    end
  end
end
