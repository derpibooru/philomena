defmodule PhilomenaMedia.Analyzers.Analyzer do
  @moduledoc false

  @doc """
  Generate a `m:PhilomenaMedia.Analyzers.Result` for file at the given path.
  """
  @callback analyze(Path.t()) :: PhilomenaMedia.Analyzers.Result.t()
end
