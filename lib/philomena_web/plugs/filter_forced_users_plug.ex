defmodule PhilomenaWeb.FilterForcedUsersPlug do
  @moduledoc """
  Halts the request pipeline if the current image belongs to the conn's
  "forced filter".
  """

  import Phoenix.Controller
  import Plug.Conn
  alias Philomena.Search.String, as: SearchString
  alias Philomena.Search.Evaluator
  alias Philomena.Images.Query
  alias PhilomenaWeb.ImageView 

  def init(_opts) do
    []
  end

  def call(conn, _opts) do
    maybe_fetch_forced(conn, conn.assigns.forced_filter)
  end

  defp maybe_fetch_forced(conn, nil), do: conn
  defp maybe_fetch_forced(conn, forced) do
    maybe_halt(conn, matches_filter?(conn.assigns.current_user, conn.assigns.image, forced))
  end

  defp maybe_halt(conn, false), do: conn
  defp maybe_halt(conn, true) do
    conn
    |> put_flash(:error, "You have been blocked from performing this action on this image.")
    |> redirect(external: conn.assigns.referrer)
    |> halt()
  end

  defp matches_filter?(user, image, filter) do
    matches_tag_filter?(image, filter.hidden_tag_ids) or
      matches_complex_filter?(user, image, filter.hidden_complex_str)
  end

  defp matches_tag_filter?(image, tag_ids) do
    image.tags
    |> MapSet.new(& &1.id)
    |> MapSet.intersection(MapSet.new(tag_ids))
    |> Enum.any?()
  end

  defp matches_complex_filter?(user, image, search_string) do
    image
    |> ImageView.image_filter_data()
    |> Evaluator.hits?(compile_filter(user, search_string))
  end

  defp compile_filter(user, search_string) do
    case Query.compile(user, SearchString.normalize(search_string)) do
      {:ok, query} -> query
      _error -> %{match_all: %{}}
    end
  end
end
