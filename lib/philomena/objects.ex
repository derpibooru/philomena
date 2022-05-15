defmodule Philomena.Objects do
  @moduledoc """
  Replication wrapper for object storage backends.
  """
  alias Philomena.Mime

  #
  # Fetch a key from the primary storage backend and
  # write it into the destination file.
  #
  # sobelow_skip ["Traversal.FileModule"]
  @spec download_file(String.t(), String.t()) :: any()
  def download_file(key, file_path) do
    [opts] = primary_opts()

    contents =
      ExAws.S3.get_object(opts[:bucket], key)
      |> ExAws.request!(opts[:config_overrides])

    File.write!(file_path, contents.body)
  end

  #
  # Upload a file using a single API call, writing the
  # contents from the given path to storage.
  #
  # sobelow_skip ["Traversal.FileModule"]
  @spec put(String.t(), String.t()) :: any()
  def put(key, file_path) do
    {_, mime} = Mime.file(file_path)
    contents = File.read!(file_path)

    run_all(fn opts ->
      ExAws.S3.put_object(opts[:bucket], key, contents, content_type: mime)
      |> ExAws.request!(opts[:config_overrides])
    end)
  end

  #
  # Copies a key from the source to the destination,
  # overwriting the destination object if its exists.
  #
  @spec copy(String.t(), String.t()) :: any()
  def copy(source_key, dest_key) do
    run_all(fn opts ->
      ExAws.S3.put_object_copy(opts[:bucket], dest_key, opts[:bucket], source_key)
      |> ExAws.request!(opts[:config_overrides])
    end)
  end

  #
  # Removes the key from storage.
  #
  @spec delete(String.t()) :: any()
  def delete(key) do
    run_all(fn opts ->
      ExAws.S3.delete_object(opts[:bucket], key)
      |> ExAws.request!(opts[:config_overrides])
    end)
  end

  #
  # Removes all given keys from storage.
  #
  @spec delete_multiple([String.t()]) :: any()
  def delete_multiple(keys) do
    run_all(fn opts ->
      ExAws.S3.delete_multiple_objects(opts[:bucket], keys)
      |> ExAws.request!(opts[:config_overrides])
    end)
  end

  defp run_all(fun) do
    backends()
    |> Task.async_stream(fun, timeout: :infinity)
    |> Stream.run()
  end

  defp backends do
    primary_opts() ++ replica_opts()
  end

  defp primary_opts do
    [
      %{
        config_overrides: Application.fetch_env!(:philomena, :s3_primary_options),
        bucket: Application.fetch_env!(:philomena, :s3_primary_bucket)
      }
    ]
  end

  defp replica_opts do
    replica_bucket = Application.get_env(:philomena, :s3_secondary_bucket)

    if not is_nil(replica_bucket) do
      [
        %{
          config_overrides: Application.fetch_env!(:philomena, :s3_secondary_options),
          bucket: replica_bucket
        }
      ]
    else
      []
    end
  end
end
