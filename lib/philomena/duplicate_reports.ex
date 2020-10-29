defmodule Philomena.DuplicateReports do
  @moduledoc """
  The DuplicateReports context.
  """

  import Ecto.Query, warn: false
  alias Ecto.Multi
  alias Philomena.Repo

  alias Philomena.DuplicateReports.DuplicateReport
  alias Philomena.ImageIntensities.ImageIntensity
  alias Philomena.Images.Image
  alias Philomena.Images

  def generate_reports(source) do
    source = Repo.preload(source, :intensity)

    duplicates_of(source.intensity, source.image_aspect_ratio, 0.2, 0.05)
    |> where([i, _it], i.id != ^source.id)
    |> Repo.all()
    |> Enum.map(fn target ->
      create_duplicate_report(source, target, %{}, %{
        "reason" => "Automated Perceptual dedupe match"
      })
    end)
  end

  def duplicates_of(intensities, aspect_ratio, dist \\ 0.25, aspect_dist \\ 0.05) do
    from i in Image,
      inner_join: it in ImageIntensity,
      on: it.image_id == i.id,
      where: it.nw >= ^(intensities.nw - dist) and it.nw <= ^(intensities.nw + dist),
      where: it.ne >= ^(intensities.ne - dist) and it.ne <= ^(intensities.ne + dist),
      where: it.sw >= ^(intensities.sw - dist) and it.sw <= ^(intensities.sw + dist),
      where: it.se >= ^(intensities.se - dist) and it.se <= ^(intensities.se + dist),
      where:
        i.image_aspect_ratio >= ^(aspect_ratio - aspect_dist) and
          i.image_aspect_ratio <= ^(aspect_ratio + aspect_dist),
      limit: 10
  end

  @doc """
  Gets a single duplicate_report.

  Raises `Ecto.NoResultsError` if the Duplicate report does not exist.

  ## Examples

      iex> get_duplicate_report!(123)
      %DuplicateReport{}

      iex> get_duplicate_report!(456)
      ** (Ecto.NoResultsError)

  """
  def get_duplicate_report!(id), do: Repo.get!(DuplicateReport, id)

  @doc """
  Creates a duplicate_report.

  ## Examples

      iex> create_duplicate_report(%{field: value})
      {:ok, %DuplicateReport{}}

      iex> create_duplicate_report(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_duplicate_report(source, target, attribution, attrs \\ %{}) do
    %DuplicateReport{image_id: source.id, duplicate_of_image_id: target.id}
    |> DuplicateReport.creation_changeset(attrs, attribution)
    |> Repo.insert()
  end

  def accept_duplicate_report(multi \\ nil, %DuplicateReport{} = duplicate_report, user) do
    duplicate_report = Repo.preload(duplicate_report, [:image, :duplicate_of_image])

    other_duplicate_reports =
      DuplicateReport
      |> where(
        [dr],
        (dr.image_id == ^duplicate_report.image_id and
           dr.duplicate_of_image_id == ^duplicate_report.duplicate_of_image_id) or
          (dr.image_id == ^duplicate_report.duplicate_of_image_id and
             dr.duplicate_of_image_id == ^duplicate_report.image_id)
      )
      |> where([dr], dr.id != ^duplicate_report.id)
      |> update(set: [state: "rejected"])

    changeset = DuplicateReport.accept_changeset(duplicate_report, user)

    multi = multi || Multi.new()

    multi
    |> Multi.update(:duplicate_report, changeset)
    |> Multi.update_all(:other_reports, other_duplicate_reports, [])
    |> Images.merge_image(duplicate_report.image, duplicate_report.duplicate_of_image, user)
  end

  def accept_reverse_duplicate_report(%DuplicateReport{} = duplicate_report, user) do
    new_report =
      DuplicateReport
      |> where(duplicate_of_image_id: ^duplicate_report.image_id)
      |> limit(1)
      |> Repo.one()

    new_report =
      if new_report do
        new_report
      else
        %DuplicateReport{
          image_id: duplicate_report.duplicate_of_image_id,
          duplicate_of_image_id: duplicate_report.image_id,
          reason: Enum.join([duplicate_report.reason, "(Reverse accepted)"], "\n"),
          user_id: user.id
        }
        |> DuplicateReport.changeset(%{})
        |> Repo.insert!()
      end

    Multi.new()
    |> Multi.run(:reject_duplicate_report, fn _, %{} ->
      reject_duplicate_report(duplicate_report, user)
    end)
    |> accept_duplicate_report(new_report, user)
  end

  def claim_duplicate_report(%DuplicateReport{} = duplicate_report, user) do
    duplicate_report
    |> DuplicateReport.claim_changeset(user)
    |> Repo.update()
  end

  def unclaim_duplicate_report(%DuplicateReport{} = duplicate_report) do
    duplicate_report
    |> DuplicateReport.unclaim_changeset()
    |> Repo.update()
  end

  def reject_duplicate_report(%DuplicateReport{} = duplicate_report, user) do
    duplicate_report
    |> DuplicateReport.reject_changeset(user)
    |> Repo.update()
  end

  @doc """
  Deletes a DuplicateReport.

  ## Examples

      iex> delete_duplicate_report(duplicate_report)
      {:ok, %DuplicateReport{}}

      iex> delete_duplicate_report(duplicate_report)
      {:error, %Ecto.Changeset{}}

  """
  def delete_duplicate_report(%DuplicateReport{} = duplicate_report) do
    Repo.delete(duplicate_report)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking duplicate_report changes.

  ## Examples

      iex> change_duplicate_report(duplicate_report)
      %Ecto.Changeset{source: %DuplicateReport{}}

  """
  def change_duplicate_report(%DuplicateReport{} = duplicate_report) do
    DuplicateReport.changeset(duplicate_report, %{})
  end

  def count_duplicate_reports(user) do
    if Canada.Can.can?(user, :index, DuplicateReport) do
      DuplicateReport
      |> where(state: "open")
      |> Repo.aggregate(:count, :id)
    else
      nil
    end
  end
end
