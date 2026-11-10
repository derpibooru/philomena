defmodule Philomena.Users.Uploader do
  @moduledoc """
  Upload and processing callback logic for User avatars.
  """

  alias Philomena.Multi
  alias Philomena.Users.User
  alias PhilomenaMedia.Uploader

  def analyze_upload(user, upload) do
    Uploader.analyze_upload(user, "avatar", upload, &User.avatar_changeset/2)
  end

  def put_persist_upload_and_unpersist_old(multi, step) do
    Multi.on_commit(multi, fn %{^step => user} ->
      Uploader.persist_upload(user, avatar_file_root(), "avatar")
      Uploader.unpersist_old_upload(user, avatar_file_root(), "avatar")
    end)
  end

  def put_unpersist_old_upload(multi, step) do
    Multi.on_commit(multi, fn %{^step => user} ->
      Uploader.unpersist_old_upload(user, avatar_file_root(), "avatar")
    end)
  end

  defp avatar_file_root do
    Application.get_env(:philomena, :avatar_file_root)
  end
end
