defmodule PhilomenaWeb.Image.SourceController do
  use PhilomenaWeb, :controller

  alias Philomena.Images.Source
  alias Philomena.Images
  alias PhilomenaWeb.RateLimitedResponse

  action_fallback PhilomenaWeb.FallbackController

  plug PhilomenaWeb.CaptchaPlug
  plug PhilomenaWeb.CheckCaptchaPlug

  def update(conn, %{"image" => image_params} = params) do
    case Images.update_image_sources(conn.assigns.actor, params["image_id"], image_params) do
      {:ok, %{image: image, source_change_count: count}} ->
        changeset =
          %{image | sources: sources_for_edit(image.sources)}
          |> Images.change_image()

        conn
        |> put_view(PhilomenaWeb.ImageView)
        |> render("_source.html",
          layout: false,
          source_change_count: count,
          image: image,
          changeset: changeset
        )

      {:error, %Ecto.Changeset{} = changeset} ->
        conn
        |> put_view(PhilomenaWeb.ImageView)
        |> render("_source.html",
          layout: false,
          source_change_count: 0,
          image: changeset.data,
          changeset: changeset
        )

      {:error, :rate_limited} ->
        RateLimitedResponse.call(conn, "You may only update metadata once every 5 seconds.")

      {:error, _} = error ->
        error
    end
  end

  defp sources_for_edit(), do: [%Source{}]
  defp sources_for_edit([]), do: sources_for_edit()
  defp sources_for_edit(sources), do: sources
end
