defmodule PhilomenaMedia.Strip do
  @moduledoc false

  alias PhilomenaMedia.Icc
  alias PhilomenaMedia.Remote

  @spec requires_strip?(Path.t()) :: boolean()
  def requires_strip?(file) do
    with {output, 0} <-
           Remote.cmd("magick", ["identify", "-format", "%[orientation]\t%[profile:icc]", file]),
         [orientation, profile] <- String.split(output, "\t") do
      orientation not in ["Undefined", "TopLeft"] or
        (profile != "" and not Icc.srgb_profile?(file))
    else
      _ ->
        true
    end
  end

  @spec strip(Path.t(), String.t()) :: Path.t()
  def strip(file, extname) do
    stripped = Briefly.create!(extname: extname)

    {_output, 0} =
      Remote.cmd("magick", [
        file,
        "-profile",
        Icc.srgb_profile(),
        "-auto-orient",
        "-strip",
        stripped
      ])

    stripped
  end
end
