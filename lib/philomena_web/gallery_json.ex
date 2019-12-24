defmodule PhilomenaWeb.GalleryJson do
  def as_json(gallery) do
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