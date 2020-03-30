defmodule PhilomenaWeb.Api.Json.GalleryView do
  use PhilomenaWeb, :view

  def render("index.json", %{galleries: galleries, total: total} = assigns) do
    %{
      galleries: render_many(galleries, PhilomenaWeb.Api.Json.GalleryView, "gallery.json", assigns),
      total: total
    }
  end

  def render("show.json", %{gallery: gallery} = assigns) do
    %{gallery: render_one(gallery, PhilomenaWeb.Api.Json.GalleryView, "gallery.json", assigns)}
  end

  def render("gallery.json", %{gallery: gallery}) do
    %{
      id: gallery.id,
      title: gallery.title,
      thumbnail_id: gallery.thumbnail_id,
      spoiler_warning: gallery.spoiler_warning,
      description: gallery.description,
      user: gallery.creator.name,
      user_id: gallery.creator_id
    }
  end
end
