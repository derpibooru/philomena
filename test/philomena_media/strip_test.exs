defmodule PhilomenaMedia.StripTest do
  use ExUnit.Case, async: true

  alias PhilomenaMedia.Strip

  test "strip/2 raises for a file ImageMagick cannot decode" do
    corrupt = Briefly.create!(extname: ".png")
    File.write!(corrupt, "not a png")

    assert Strip.requires_strip?(corrupt)
    assert_raise MatchError, fn -> Strip.strip(corrupt, ".png") end
  end
end
