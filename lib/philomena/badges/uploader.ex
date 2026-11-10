defmodule Philomena.Badges.Uploader do
  @moduledoc """
  Upload and processing callback logic for Badge images.
  """

  alias Philomena.Multi
  alias Philomena.Badges.Badge
  alias PhilomenaMedia.Uploader

  def analyze_upload(badge, upload) do
    Uploader.analyze_upload(badge, "image", upload, &Badge.image_changeset/2)
  end

  def put_persist_upload_and_unpersist_old(multi, step) do
    Multi.on_commit(multi, fn %{^step => badge} ->
      Uploader.persist_upload(badge, badge_file_root(), "image")
      Uploader.unpersist_old_upload(badge, badge_file_root(), "image")
    end)
  end

  def put_unpersist_old_upload(multi, step) do
    Multi.on_commit(multi, fn %{^step => badge} ->
      Uploader.unpersist_old_upload(badge, badge_file_root(), "image")
    end)
  end

  defp badge_file_root do
    Application.get_env(:philomena, :badge_file_root)
  end
end
