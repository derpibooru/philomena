defmodule PhilomenaWeb.ImageReverse do
  alias Philomena.Processors
  alias Philomena.DuplicateReports
  alias Philomena.Repo
  import Ecto.Query

  def images(image_params) do
    image_params
    |> Map.get("image")
    |> Map.get(:path)
    |> mime()
    |> analyze()
    |> intensities()
    |> case do
      :error ->
        []

      {analysis, intensities} ->
        {width, height} = analysis.dimensions
        aspect = width / height
        dist = normalize_dist(image_params)

        DuplicateReports.duplicates_of(intensities, aspect, dist, dist)
        |> preload([:tags, :user])
        |> Repo.all()
    end
  end

  defp mime(file) do
    {:ok, mime} = Philomena.Mime.file(file)

    {mime, file}
  end

  defp analyze({mime, file}) do
    case Processors.analyzers(mime) do
      nil -> :error
      a   -> {a.analyze(file), mime, file}
    end
  end

  defp intensities(:error), do: :error
  defp intensities({analysis, mime, file}) do
    {analysis, Processors.processors(mime).intensities(analysis, file)}
  end

  # The distance metric is taxicab distance, not Euclidean,
  # because this is more efficient to index.
  defp normalize_dist(%{"distance" => distance}) do
    distance
    |> String.to_float()
    |> max(0.01)
    |> min(1.0)
  end
  defp normalize_dist(_dist), do: 0.25
end