defmodule PhilomenaMedia.Objects do
  @moduledoc """
  Replication wrapper for object storage backends.

  While cloud services can be an inexpensive way to access large amounts of storage, they
  are inherently less available than local file-based storage. For this reason, it is generally
  recommended to maintain a secondary storage provider, such as in the
  [3-2-1 backup strategy](https://www.backblaze.com/blog/the-3-2-1-backup-strategy/).

  Functions in this module replicate operations on both the primary and secondary storage
  providers. Alternatively, a mode with only a primary storage provider is supported.

  This module assumes storage endpoints are S3-compatible and can be communicated with via the
  `m:ExAws` module. This does not preclude the usage of local file-based storage, which can be
  accomplished with the [`s3proxy` project](https://github.com/gaul/s3proxy). The development
  repository provides an example of `s3proxy` in use.

  Bucket names should be set with configuration on `s3_primary_bucket` and `s3_secondary_bucket`.
  If `s3_secondary_bucket` is not set, then only the primary will be used. However, the primary
  bucket name must always be set.

  These are read from environment variables at runtime by Philomena.

      # S3/Object store config
      config :philomena, :s3_primary_bucket, System.fetch_env!("S3_BUCKET")
      config :philomena, :s3_secondary_bucket, System.get_env("ALT_S3_BUCKET")

  Additional options (e.g. controlling the remote endpoint used) may be set with
  `s3_primary_options` and `s3_secondary_options` keys. This allows you to use a provider other
  than AWS, like [Cloudflare R2](https://developers.cloudflare.com/r2/).

  These are read from environment variables at runtime by Philomena.

      config :philomena, :s3_primary_options,
        region: System.get_env("S3_REGION", "us-east-1"),
        scheme: System.fetch_env!("S3_SCHEME"),
        host: System.fetch_env!("S3_HOST"),
        port: System.fetch_env!("S3_PORT"),
        access_key_id: System.fetch_env!("AWS_ACCESS_KEY_ID"),
        secret_access_key: System.fetch_env!("AWS_SECRET_ACCESS_KEY"),
        http_opts: [timeout: 180_000, recv_timeout: 180_000]

  """
  alias PhilomenaMedia.Mime
  require Logger

  @type key :: String.t()

  @doc """
  Fetch a key from the storage backend and write it into the destination path.

  ## Example

      key = "2024/1/1/5/full.png"
      Objects.download_file(key, file_path)

  """
  # sobelow_skip ["Traversal.FileModule"]
  @spec download_file(key(), Path.t()) :: :ok
  def download_file(key, file_path) do
    contents =
      backends()
      |> Enum.find_value(fn opts ->
        ExAws.S3.get_object(opts[:bucket], key)
        |> ExAws.request(opts[:config_overrides])
        |> case do
          {:ok, result} -> result
          _ -> nil
        end
      end)

    File.write!(file_path, contents.body)
  end

  @doc """
  Upload a file using a single API call, writing the contents from the given path to storage.

  ## Example

      key = "2024/1/1/5/full.png"
      Objects.put(key, file_path)

  """
  # sobelow_skip ["Traversal.FileModule"]
  @spec put(key(), Path.t()) :: :ok
  def put(key, file_path) do
    {_, mime} = Mime.file(file_path)
    contents = File.read!(file_path)

    run_all(fn opts ->
      ExAws.S3.put_object(opts[:bucket], key, contents, content_type: mime)
      |> ExAws.request!(opts[:config_overrides])
    end)
  end

  @doc """
  Upload a file using multiple API calls, writing the contents from the given path to storage.

  ## Example

      key = "2024/1/1/5/full.png"
      Objects.upload(key, file_path)

  """
  @spec upload(key(), Path.t()) :: :ok
  def upload(key, file_path) do
    # Workaround for API rate limit issues on R2
    put(key, file_path)
  end

  @doc """
  Copies a key from the source to the destination, overwriting the destination object if its exists.

  > #### Warning {: .warning}
  >
  > `copy/2` does not use the `PutObjectCopy` S3 request. It downloads the file and uploads it again.
  > This may use more disk space than expected if the file is large.

  ## Example

      source_key = "2024/1/1/5/full.png"
      dest_key = "2024/1/1/5-a5323e542e0f/full.png"
      Objects.copy(source_key, dest_key)

  """
  @spec copy(key(), key()) :: :ok
  def copy(source_key, dest_key) do
    # Potential workaround for inconsistent PutObjectCopy on R2
    #
    # run_all(fn opts->
    #   ExAws.S3.put_object_copy(opts[:bucket], dest_key, opts[:bucket], source_key)
    #   |> ExAws.request!(opts[:config_overrides])
    # end)

    try do
      file_path = Briefly.create!()
      download_file(source_key, file_path)
      upload(dest_key, file_path)
    catch
      _kind, _value -> Logger.warning("Failed to copy #{source_key} -> #{dest_key}")
    end

    :ok
  end

  @doc """
  Removes the key from storage.

  ## Example

      key = "2024/1/1/5/full.png"
      Objects.delete(key)

  """
  @spec delete(key()) :: :ok
  def delete(key) do
    run_all(fn opts ->
      ExAws.S3.delete_object(opts[:bucket], key)
      |> ExAws.request!(opts[:config_overrides])
    end)
  end

  @doc """
  Removes all given keys from storage.

  ## Example

      keys = [
        "2024/1/1/5/full.png",
        "2024/1/1/5/small.png",
        "2024/1/1/5/thumb.png",
        "2024/1/1/5/thumb_tiny.png"
      ]
      Objects.delete_multiple(keys)

  """
  @spec delete_multiple([key()]) :: :ok
  def delete_multiple(keys) do
    run_all(fn opts ->
      ExAws.S3.delete_multiple_objects(opts[:bucket], keys)
      |> ExAws.request!(opts[:config_overrides])
    end)
  end

  defp run_all(wrapped) do
    fun = fn opts ->
      try do
        wrapped.(opts)
        :ok
      catch
        _kind, _value -> :error
      end
    end

    backends()
    |> Task.async_stream(fun, timeout: :infinity)
    |> Enum.any?(fn {_, v} -> v == :error end)
    |> if do
      Logger.warning("Failed to operate on all backends")
    else
      :ok
    end

    :ok
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
