defmodule PhilomenaMedia.Processors.PngTest do
  use ExUnit.Case, async: true

  alias PhilomenaMedia.Analyzers
  alias PhilomenaMedia.Processors.Png
  alias PhilomenaMedia.Remote

  @fixture Path.absname("test/support/fixtures/files/upload-test.png")

  test "keeps an sRGB PNG without orientation as uploaded" do
    edit_script = process(@fixture)

    refute Keyword.has_key?(edit_script, :replace_original)
    assert [{:copy, _, "thumb.png"}] = edit_script[:thumbnails]
  end

  test "replaces a rotated PNG with an upright stripped copy" do
    rotated = Briefly.create!(extname: ".png")

    {_output, 0} =
      Remote.cmd("magick", ["-size", "2x1", "xc:red", "-orient", "RightTop", rotated])

    stripped = process(rotated)[:replace_original]

    assert {"1x2 TopLeft", 0} =
             Remote.cmd("magick", ["identify", "-format", "%wx%h %[orientation]", stripped])
  end

  defp process(file) do
    {:ok, analysis} = Analyzers.analyze_path(file)
    Png.process(analysis, file, thumb: {50, 50})
  end
end
