defmodule PhilomenaMedia.StripTest do
  use ExUnit.Case, async: true

  alias PhilomenaMedia.Strip

  test "strip/2 returns an error for a file ImageMagick cannot decode" do
    corrupt = Briefly.create!(extname: ".png")
    File.write!(corrupt, "not a png")

    assert Strip.requires_strip?(corrupt)
    assert Strip.strip(corrupt, ".png") == :error
  end
end
