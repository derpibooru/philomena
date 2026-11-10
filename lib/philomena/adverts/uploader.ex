defmodule Philomena.Adverts.Uploader do
  @moduledoc """
  Upload and processing callback logic for Advert images.
  """

  alias Philomena.Multi
  alias Philomena.Adverts.Advert
  alias PhilomenaMedia.Uploader

  def analyze_upload(advert, upload) do
    Uploader.analyze_upload(advert, "image", upload, &Advert.image_changeset/2)
  end

  def put_persist_upload_and_unpersist_old(multi, step) do
    Multi.on_commit(multi, fn %{^step => advert} ->
      Uploader.persist_upload(advert, advert_file_root(), "image")
      Uploader.unpersist_old_upload(advert, advert_file_root(), "image")
    end)
  end

  def put_unpersist_old_upload(multi, step) do
    Multi.on_commit(multi, fn %{^step => advert} ->
      Uploader.unpersist_old_upload(advert, advert_file_root(), "image")
    end)
  end

  defp advert_file_root do
    Application.get_env(:philomena, :advert_file_root)
  end
end
