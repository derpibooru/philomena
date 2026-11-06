defmodule PhilomenaWeb.ImageFilterPlugTest do
  use ExUnit.Case, async: true

  import Plug.Conn
  import Plug.Test

  alias Philomena.Attribution.Actor
  alias Philomena.Filters.Filter
  alias Philomena.Filters.ImageFilter
  alias PhilomenaWeb.ImageFilterPlug

  @actor %Actor{ip: %Postgrex.INET{address: {203, 0, 113, 1}, netmask: 32}}

  test "assigns the compiled domain filter state" do
    conn =
      conn(:get, "/")
      |> assign(:actor, @actor)
      |> assign(:current_filter, %Filter{})
      |> assign(:forced_filter, nil)
      |> ImageFilterPlug.call([])

    assert %ImageFilter{} = conn.assigns.image_filter
    refute conn.halted
  end
end
