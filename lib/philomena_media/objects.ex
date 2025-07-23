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
  alias ExAws.S3
  require Logger

  @type key :: String.t()
  @typep operation_fn :: (... -> ExAws.Operation.S3.t())

  @doc """
  Creates S3 buckets for all configured storage backends.
  """
  @spec create_buckets() :: :ok
  def create_buckets do
    replicate_request(&ExAws.S3.put_bucket/2, &[&1[:bucket], &1[:config_overrides][:region]])
  end

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
        case request(&S3.get_object/2, [opts[:bucket], key], opts) do
          {:ok, contents} ->
            contents

          {:error, _} ->
            nil
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

    replicate_request(
      &S3.put_object/4,
      &[&1[:bucket], key, {:log_byte_size, contents}, [content_type: mime]]
    )
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
    # replicate_request(ExAws.S3.put_object_copy/4, &[&1[:bucket], dest_key, &1[:bucket], source_key])
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
    replicate_request(&S3.delete_object/2, &[&1[:bucket], key])
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
    replicate_request(&S3.delete_multiple_objects/2, &[&1[:bucket], keys])
  end

  # Run the S3 operation with the given list of arguments. The `opts` parameter
  # is used to select the specific S3 backend to run the operation against. See
  # the functions `primary_opts/0` and `replica_opts/0` responsible for reading
  # the config for the primary and replica S3-compatible storages.
  #
  # This function serves as a thin wrapper over this call:
  # ```ex
  # operation_fn(...args) |> ExAws.request(opts[:config_overrides])
  # ```
  #
  # Everything else in this function is just logging the request and the
  # potential error.
  #
  # # Huge Payloads Logging
  #
  # There is a special case of the `s3:PutObject` request that accepts a binary
  # payload to upload with the maximum size of 5GB (according to AWS limits).
  # For this use case, this function specially handles arguments in the `args`
  # list of shape `{:log_byte_size, binary}`. This is used to log the size of the
  # binary payload in MB instead of logging the entire payload itself, which
  # would be wasteful and useless.
  @spec request(operation_fn(), [term()], keyword()) :: term()
  defp request(operation, args, opts) do
    {:name, operation_name} = Function.info(operation, :name)

    Logger.debug(fn ->
      args_debug =
        args
        |> Enum.map(fn
          {:log_byte_size, arg} -> "#{(byte_size(arg) / 1_000_000) |> Float.round(2)} MB"
          arg -> inspect(arg)
        end)
        |> Enum.join(", ")

      "S3.#{operation_name}(#{args_debug})"
    end)

    args =
      args
      |> Enum.map(fn
        {:log_byte_size, arg} -> arg
        arg -> arg
      end)

    operation
    |> apply(args)
    |> ExAws.request(opts[:config_overrides])
    |> case do
      {:ok, output} ->
        {:ok, output}

      # Specially handle the `:http_error` case. This is the most frequent error
      # that can happen when the S3 backend responds with an error like
      # `BucketNotFound` or `InvalidRequest`. In this case we are most
      # interested in the response status and body which fully describe the
      # error. We do it this way to provide nicer formatting for such errors.
      {:error, {:http_error, status_code, %{body: body}} = err} ->
        Logger.warning(
          "S3.#{operation_name} failed (HTTP #{inspect(status_code)})\nError: #{body}"
        )

        {:error, err}

      # This is a less likely generic case of an error like connection timeout
      {:error, err} ->
        Logger.warning("S3.#{operation_name} failed\nError: #{inspect(err, pretty: true)}")
        {:error, err}
    end
  end

  # Run the S3 request across the primary and replica backends. This is only
  # useful for mutating operations that need to write the new changes to both
  # destinations. Any errors will be just logged and **not** propagated to the
  # caller.
  #
  # Ideally, a pro-active alert could be triggered to notify the ops about the
  # issue immediately so they fix the problem and retry the upload. We'll leave
  # this improvement for another day.
  @spec replicate_request(operation_fn(), (keyword() -> [term()])) :: :ok
  defp replicate_request(operation, args) do
    {:name, operation_name} = Function.info(operation, :name)
    backends = backends()

    total_err =
      backends
      |> Task.async_stream(&request(operation, args.(&1), &1), timeout: :infinity)
      |> Enum.filter(&(not match?({:ok, {:ok, _}}, &1)))
      |> Enum.count()

    cond do
      total_err > 0 and total_err == length(backends) ->
        Logger.error("S3.#{operation_name} failed for all (#{total_err}) backends")

      total_err > 0 ->
        Logger.warning("S3.#{operation_name} failed for #{total_err} backends")

      true ->
        :ok
    end
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
