defmodule PhilomenaWeb.ImageReverse do
  alias Philomena.Analyzers
  alias Philomena.Processors
  alias Philomena.DuplicateReports
  alias Philomena.Repo
  import Ecto.Query

  def images(image_params) do
    image_params
    |> Map.get("image")
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
        |> preload([:user, :intensity, [tags: :aliases]])
        |> Repo.all()
    end
  end

  defp analyze(%Plug.Upload{path: path}) do
    case Analyzers.analyze(path) do
      {:ok, analysis} -> {analysis, path}
      _ -> :error
    end
  end

  defp analyze(_upload), do: :error

  defp intensities(:error), do: :error

  defp intensities({analysis, path}) do
    {analysis, Processors.intensities(analysis, path)}
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
