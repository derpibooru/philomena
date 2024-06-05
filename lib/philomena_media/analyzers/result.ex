defmodule PhilomenaMedia.Analyzers.Result do
  @moduledoc """
  The analysis result.

  - `:animated?` - whether the media file is animated
  - `:dimensions` - the maximum dimensions of the media file, as `{width, height}`
  - `:duration` - the maximum duration of the media file, or 0 if not applicable
  - `:extension` - the file extension the media file should take, based on its contents
  - `:mime_type` - the MIME type the media file should take, based on its contents

  ## Example

      %Result{
        animated?: false,
        dimensions: {800, 600},
        duration: 0.0,
        extension: "png",
        mime_type: "image/png"
      }

  """

  @type t :: %__MODULE__{
          animated?: boolean(),
          dimensions: {integer(), integer()},
          duration: float(),
          extension: String.t(),
          mime_type: String.t()
        }

  defstruct animated?: false,
            dimensions: {0, 0},
            duration: 0.0,
            extension: "",
            mime_type: "application/octet-stream"
end
