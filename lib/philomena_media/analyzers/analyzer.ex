defmodule PhilomenaMedia.Analyzers.Analyzer do
  @moduledoc false

  @callback analyze(Path.t()) :: PhilomenaMedia.Analyzers.Result.t()
end
