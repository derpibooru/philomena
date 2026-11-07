defmodule PhilomenaMedia.Processors.JpegTest do
  use ExUnit.Case, async: true

  alias PhilomenaMedia.Analyzers
  alias PhilomenaMedia.Processors.Jpeg
  alias PhilomenaMedia.Remote

  # EXIF APP1 segment holding a single Orientation tag set to RightTop
  @exif_right_top <<0xFF, 0xE1, 34::16, "Exif", 0, 0, "MM", 42::16, 8::32, 1::16, 0x0112::16,
                    3::16, 1::32, 6::16, 0::16, 0::32>>

  test "replaces an upright JPEG with a lossless copy without metadata" do
    upright = jpeg()

    edit_script = process(upright)

    assert {"2x1 Undefined ", 0} = identify(edit_script[:replace_original])
    assert [{:copy, _, "thumb.jpg"}] = edit_script[:thumbnails]
  end

  test "replaces a rotated JPEG with an upright stripped copy" do
    rotated = jpeg()
    <<0xFF, 0xD8, rest::binary>> = File.read!(rotated)
    File.write!(rotated, <<0xFF, 0xD8>> <> @exif_right_top <> rest)

    assert {"1x2 Undefined ", 0} = identify(process(rotated)[:replace_original])
  end

  defp jpeg do
    file = Briefly.create!(extname: ".jpg")
    {_output, 0} = Remote.cmd("magick", ["-size", "2x1", "xc:red", "-set", "comment", "x", file])
    file
  end

  defp identify(file) do
    Remote.cmd("magick", ["identify", "-format", "%wx%h %[orientation] %c", file])
  end

  defp process(file) do
    {:ok, analysis} = Analyzers.analyze_path(file)
    Jpeg.process(analysis, file, thumb: {50, 50})
  end
end
