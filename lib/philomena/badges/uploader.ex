defmodule Philomena.Badges.Uploader do
  @moduledoc """
  Upload and processing callback logic for Badge images.
  """

  alias Philomena.Badges.Badge
  alias Philomena.Uploader

  def analyze_upload(badge, params) do
    Uploader.analyze_upload(badge, "image", params["image"], &Badge.image_changeset/2)
  end

  def persist_upload(badge) do
    Uploader.persist_upload(badge, badge_file_root(), "image")
  end

  def unpersist_old_upload(badge) do
    Uploader.unpersist_old_upload(badge, badge_file_root(), "image")
  end

  defp badge_file_root do
    Application.get_env(:philomena, :badge_file_root)
  end
end
