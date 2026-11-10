defmodule Philomena.DuplicateReports.TransactionWorkflow do
  @moduledoc """
  Composable locking steps for duplicate-report transactions.

  A duplicate report is identified by an ordered source/target pair, but the
  operations that act on it are mutually exclusive for the unordered image
  pair. Accepting a report can merge its images and reject other reports in
  either direction; creating, claiming, unclaiming, or rejecting a report must
  not race with that work. Historical duplicate report rows are therefore not
  the serialization boundary: locking every row for a pair would be
  unbounded, and a newly inserted row could otherwise appear after a report
  query has completed.

  The image rows are the pair mutex. Every mutating duplicate report workflow
  must lock the distinct image IDs in ascending order before reading or
  changing report state. This serializes all compliant operations for the
  unordered pair and prevents opposite-direction operations from deadlocking.
  After the image locks are acquired, workflows reload the report state they
  need. The subject report may also be locked as a convenient existence check,
  but that lock is supplementary to the image pair lock. All locks and the
  mutation must belong to the same `Philomena.Multi` transaction.

  `put_lock_image_pair/5` additionally authorizes both locked images,
  `put_lock_image_pair_without_authorization/3` is for trusted internal work
  such as automated report generation, and
  `put_lock_image_pair_and_report/5` also reloads and locks one subject report
  before authorizing it. Callers must not perform report mutations through a
  path that skips the image-pair lock.
  """

  import Philomena.Authorization, only: [authorize: 3]
  import Ecto.Query

  alias Philomena.Attribution.Actor
  alias Philomena.DuplicateReports.DuplicateReport
  alias Philomena.Images.Image
  alias Philomena.IntegerId
  alias Philomena.Multi

  @doc """
  Adds ordered row locks for both images and authorizes `actor` for `action`
  on each image.

  Use this before creating a duplicate report or before composing another
  report mutation that needs the unordered image pair as its serialization
  boundary. The transaction receives `:locked_source_image`,
  `:locked_target_image`, and `:authorize` steps. Missing images fail as
  `:not_found`; failed authorization fails as `:unauthorized`.

  ## Examples

      iex> Multi.new() |> put_lock_image_pair(actor, 10, 20, :show)
      %Multi{}

  """
  @spec put_lock_image_pair(
          multi :: Multi.t(),
          actor :: Actor.t(),
          source_id :: IntegerId.integer_id(),
          target_id :: IntegerId.integer_id(),
          action :: atom()
        ) :: Multi.t()
  def put_lock_image_pair(
        %Multi{} = multi,
        %Actor{} = actor,
        source_id,
        target_id,
        action
      ) do
    multi
    |> lock_image_pair(source_id, target_id)
    |> Multi.run(:authorize, fn _repo,
                                %{
                                  locked_source_image: source_image,
                                  locked_target_image: target_image
                                } ->
      with :ok <- authorize(actor, action, source_image),
           :ok <- authorize(actor, action, target_image) do
        {:ok, nil}
      end
    end)
  end

  @doc """
  Adds ordered image pair locks without performing authorization.

  This is restricted to trusted internal workflows that already establish
  their own safety conditions, such as automated duplicate-report generation.
  It must still be composed in the same transaction as the report insert or
  other mutation. The transaction receives `:locked_source_image` and
  `:locked_target_image` steps.

  ## Examples

      iex> Multi.new() |> put_lock_image_pair_without_authorization(10, 20)
      %Multi{}

  """
  @spec put_lock_image_pair_without_authorization(
          multi :: Multi.t(),
          source_id :: IntegerId.integer_id(),
          target_id :: IntegerId.integer_id()
        ) :: Multi.t()
  def put_lock_image_pair_without_authorization(%Multi{} = multi, source_id, target_id) do
    lock_image_pair(multi, source_id, target_id)
  end

  @doc """
  Adds ordered image pair locks and a row lock for one duplicate report.

  The supplied report is only a locator for the image pair and report ID. The
  report is reloaded after the image locks are acquired, with its original
  direction verified. `image_action` is checked against both locked images and
  `action` is checked against the locked report. The transaction receives
  `:locked_source_image`, `:locked_target_image`,
  `:locked_duplicate_report`, and `:authorize` steps.

  Use this for claim, unclaim, reject, accept, and reverse-accept workflows.
  Accept workflows can then query all reports for the locked image pair
  without locking the unbounded historical set; the image locks serialize
  those queries with every compliant report mutation.

  ## Examples

      iex> Multi.new() |> put_lock_image_pair_and_report(report, actor, :show, :accept)
      %Multi{}

  """
  @spec put_lock_image_pair_and_report(
          multi :: Multi.t(),
          duplicate_report :: DuplicateReport.t(),
          actor :: Actor.t(),
          image_action :: atom(),
          action :: atom()
        ) :: Multi.t()
  def put_lock_image_pair_and_report(
        %Multi{} = multi,
        %DuplicateReport{image_id: source_id, duplicate_of_image_id: target_id} = duplicate_report,
        %Actor{} = actor,
        image_action,
        action
      ) do
    # The argument duplicate report is used only as a locator for the image pair;
    # it must be reloaded after locks are acquired.
    duplicate_report_query =
      from report in DuplicateReport,
        where:
          report.id == ^duplicate_report.id and
            report.image_id == ^source_id and
            report.duplicate_of_image_id == ^target_id

    multi
    |> lock_image_pair(source_id, target_id)
    |> Multi.lock_one(:locked_duplicate_report, duplicate_report_query)
    |> Multi.run(:authorize, fn _repo,
                                %{
                                  locked_source_image: source_image,
                                  locked_target_image: target_image,
                                  locked_duplicate_report: duplicate_report
                                } ->
      with :ok <- authorize(actor, image_action, source_image),
           :ok <- authorize(actor, image_action, target_image),
           :ok <- authorize(actor, action, duplicate_report) do
        {:ok, nil}
      end
    end)
  end

  @doc """
  Converts a transaction error from a locking workflow to its public error.

  Authorization and missing-row errors are reduced to `{:error,
  :unauthorized}` and `{:error, :not_found}`, respectively. Other transaction
  results are intentionally not handled by this helper. Use it only after
  `Multi.transact/1` on a workflow that installed one of this module's locking
  helpers; it does not translate changeset failures.

  ## Examples

      iex> map_lock_errors({:error, :authorize, :unauthorized, %{}})
      {:error, :unauthorized}

  """
  @spec map_lock_errors(Multi.failure()) :: {:error, :not_found | :unauthorized}
  def map_lock_errors(result) do
    case result do
      {:error, _step, :unauthorized, _changes} ->
        {:error, :unauthorized}

      {:error, _step, :not_found, _changes} ->
        {:error, :not_found}
    end
  end

  defp lock_image_pair(%Multi{} = multi, source_id, target_id) do
    # Image pair locking occurs in a consistent order to avoid deadlock.
    [source_id, target_id]
    |> Enum.uniq()
    |> Enum.sort()
    |> Enum.reduce(multi, fn image_id, multi ->
      image_query =
        from image in Image,
          where: image.id == ^image_id

      Multi.lock_one(multi, {:locked_image, image_id}, image_query)
    end)
    |> Multi.run(:locked_source_image, fn _repo, %{{:locked_image, ^source_id} => source_image} ->
      {:ok, source_image}
    end)
    |> Multi.run(:locked_target_image, fn _repo, %{{:locked_image, ^target_id} => target_image} ->
      {:ok, target_image}
    end)
  end
end
