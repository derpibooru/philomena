defmodule PhilomenaMedia.Processors.Processor do
  @moduledoc false

  alias PhilomenaMedia.Analyzers.Result
  alias PhilomenaMedia.Processors
  alias PhilomenaMedia.Intensities

  # Generate a list of version filenames for the given version list.
  @callback versions(Processors.version_list()) :: [Processors.version_filename()]

  # Process the media at the given path against the given version list, and return an
  # edit script with the resulting files
  @callback process(Result.t(), Path.t(), Processors.version_list()) :: Processors.edit_script()

  # Perform post-processing optimization tasks on the file, to reduce its size
  # and strip non-essential metadata
  @callback post_process(Result.t(), Path.t()) :: Processors.edit_script()

  # Generate corner intensities for the given path
  @callback intensities(Result.t(), Path.t()) :: Intensities.t()
end
