defmodule PhilomenaWeb.ImageReverse do
  alias PhilomenaMedia.Analyzers
  alias PhilomenaMedia.Processors
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
        dist = parse_dist(image_params)
        limit = parse_limit(image_params)

        {intensities, aspect}
        |> DuplicateReports.find_duplicates(dist: dist, aspect_dist: dist, limit: limit)
        |> preload([:user, :intensity, [:sources, tags: :aliases]])
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
  defp parse_dist(%{"distance" => distance}) do
    distance
    |> Decimal.parse()
    |> case do
      {value, _rest} -> Decimal.to_float(value)
      _ -> 0.25
    end
    |> clamp(0.01, 1.0)
  end

  defp parse_dist(_params), do: 0.25

  defp parse_limit(%{"limit" => limit}) do
    limit
    |> Integer.parse()
    |> case do
      {limit, _rest} -> limit
      _ -> 10
    end
    |> clamp(1, 50)
  end

  defp parse_limit(_params), do: 10

  defp clamp(n, min, _max) when n < min, do: min
  defp clamp(n, _min, max) when n > max, do: max
  defp clamp(n, _min, _max), do: n
end
