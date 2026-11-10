defmodule PhilomenaMedia.Icc do
  @moduledoc """
  ICC color profile handling for image files.
  """

  alias PhilomenaMedia.Remote

  @doc """
  Returns whether the embedded ICC profile is effectively equivalent to sRGB.

  This assumes the file has an embedded profile. If it does not, the extraction
  will fail and this function returns `false`.
  """
  # sobelow_skip ["Traversal.FileModule"]
  @spec srgb_profile?(Path.t()) :: boolean()
  def srgb_profile?(file) do
    profile = Briefly.create!(extname: ".icc")

    with {_output, 0} <- Remote.cmd("magick", [file, profile]),
         {test, 0} <-
           Remote.cmd("magick", [
             reference_image(),
             "-profile",
             profile,
             "-profile",
             srgb_profile(),
             "-depth",
             "8",
             "RGB:-"
           ]),
         {:ok, reference} <- File.read(reference_rgb()) do
      test == reference
    else
      _ ->
        false
    end
  end

  @doc """
  Returns the path to the bundled sRGB ICC profile.
  """
  @spec srgb_profile() :: Path.t()
  def srgb_profile do
    Path.join(File.cwd!(), "priv/icc/sRGB.icc")
  end

  defp reference_image do
    Path.join(File.cwd!(), "priv/icc/reference.png")
  end

  defp reference_rgb do
    Path.join(File.cwd!(), "priv/icc/reference.rgb")
  end
end
