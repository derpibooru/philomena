defmodule PhilomenaMedia.Uploader do
  @moduledoc """
  Upload and processing callback logic for media files.

  To use the uploader, the target schema must be modified to add at least the
  following fields, assuming the name of the field to write to the database is `foo`:

      field :foo, :string
      field :uploaded_foo, :string, virtual: true
      field :removed_foo, :string, virtual: true

  The schema should also define a changeset function which casts the file parameters. This may be
  the default changeset function, or a function specialized to accept only the file parameters. A
  minimal schema must cast at least the following to successfully upload and replace files:

      def foo_changeset(schema, attrs) do
        cast(schema, attrs, [:foo, :uploaded_foo, :removed_foo])
      end

  Additional fields may be added to perform validations. For example, specifying a field name
  `foo_mime_type` allows the creation of a MIME type filter in the changeset:

      def foo_changeset(schema, attrs) do
        schema
        |> cast(attrs, [:foo, :foo_mime_type, :uploaded_foo, :removed_foo])
        |> validate_required([:foo, :foo_mime_type])
        |> validate_inclusion(:foo_mime_type, ["image/svg+xml"])
      end

  See `analyze_upload/4` for more information about what fields may be validated in this
  fashion.

  Generally, you should expect to create a `Schemas.Uploader` module, which defines functions as
  follows, pointing to `m:PhilomenaMedia.Uploader`. Assuming the target field name is `"foo"`, then:

      defmodule Philomena.Schemas.Uploader do
        alias Philomena.Schemas.Schema
        alias PhilomenaMedia.Uploader

        @field_name "foo"

        def analyze_upload(schema, params) do
          Uploader.analyze_upload(schema, @field_name, params[@field_name], &Schema.foo_changeset/2)
        end

        def persist_upload(schema) do
          Uploader.persist_upload(schema, schema_file_root(), @field_name)
        end

        def unpersist_old_upload(schema) do
          Uploader.unpersist_old_upload(schema, schema_file_root(), @field_name)
        end

        defp schema_file_root do
          Application.get_env(:philomena, :schema_file_root)
        end
      end

  A typical context usage may then look like:

      alias Philomena.Schemas.Schema
      alias Philomena.Schemas.Uploader

      @spec create_schema(map()) :: {:ok, Schema.t()} | {:error, Ecto.Changeset.t()}
      def create_schema(attrs) do
        %Schema{}
        |> Uploader.analyze_upload(attrs)
        |> Repo.insert()
        |> case do
          {:ok, schema} ->
            Uploader.persist_upload(schema)

            {:ok, schema}

          error ->
            error
        end
      end

      @spec update_schema(Schema.t(), map()) :: {:ok, Schema.t()} | {:error, Ecto.Changeset.t()}
      def update_schema(%Schema{} = schema, attrs) do
        schema
        |> Uploader.analyze_upload(attrs)
        |> Repo.update()
        |> case do
          {:ok, schema} ->
            Uploader.persist_upload(schema)
            Uploader.unpersist_old_upload(schema)

            {:ok, schema}

          error ->
            error
        end
      end

  This forwards to the core `m:PhilomenaMedia.Uploader` logic with information about the file root.

  The file root is the location at which files of the given schema type are located under
  the storage path. For example, the file root for the Adverts schema may be
  `/srv/philomena/priv/s3/philomena/adverts` in development with the file backend,
  and just `adverts` in production with the S3 backend.

  It is not recommended to perform persist or unpersist operations in the scope of an `m:Ecto.Multi`,
  as they may block indefinitely.
  """

  alias PhilomenaMedia.Analyzers
  alias PhilomenaMedia.Filename
  alias PhilomenaMedia.Objects
  alias PhilomenaMedia.Sha512
  import Ecto.Changeset

  @type schema :: struct()
  @type schema_or_changeset :: struct() | Ecto.Changeset.t()

  @type field_name :: String.t()
  @type file_root :: String.t()

  @doc """
  Performs analysis of the specified `m:Plug.Upload`, and invokes a changeset callback on the schema
  or changeset passed in.

  The file name which will be written to is set by the assignment to the schema's `field_name`, and
  the below attributes are prefixed by the `field_name`.

  Assuming the file is successfully parsed, this will attempt to cast the following
  attributes into the specified changeset function:
  * `name` (String) - the name of the file
  * `width` (integer) - the width of the file
  * `height` (integer) - the height of the file
  * `size` (integer) - the size of the file, in bytes
  * `orig_size` (integer) - the size of the file, in bytes
  * `format` (String) - the file extension, one of `~w(gif jpg png svg webm)`, determined by reading the file
  * `mime_type` (String) - the file's sniffed MIME type, determined by reading the file
  * `duration` (float) - the duration of the media file
  * `aspect_ratio` (float) - width divided by height.
  * `orig_sha512_hash` (String) - the SHA-512 hash of the file
  * `sha512_hash` (String) - the SHA-512 hash of the file
  * `is_animated` (boolean) - whether the file contains animation

  You may design your changeset callback to accept any of these. Here is an example which accepts
  all of them:

      def foo_changeset(schema, attrs)
        cast(schema, attrs, [
          :foo,
          :foo_name,
          :foo_width,
          :foo_height,
          :foo_size,
          :foo_orig_size,
          :foo_format,
          :foo_mime_type,
          :foo_duration,
          :foo_aspect_ratio,
          :foo_orig_sha512_hash,
          :foo_sha512_hash,
          :foo_is_animated,
          :uploaded_foo,
          :removed_foo
        ])
      end

  Attributes are prefixed, so assuming a `field_name` of `"foo"`, this would result in
  the changeset function receiving attributes `"foo_name"`, `"foo_width"`, ... etc.

  Validations on the uploaded media are also possible in the changeset callback. For example,
  `m:Philomena.Adverts.Advert` performs validations on MIME type and width of its field, named
  `image`:

      def image_changeset(advert, attrs) do
        advert
        |> cast(attrs, [
          :image,
          :image_mime_type,
          :image_size,
          :image_width,
          :image_height,
          :uploaded_image,
          :removed_image
        ])
        |> validate_required([:image])
        |> validate_inclusion(:image_mime_type, ["image/png", "image/jpeg", "image/gif"])
        |> validate_inclusion(:image_width, 699..729)
      end

  The key (location to write the persisted file) is passed with the `field_name` attribute into the
  changeset callback. The key is calculated using the current date, a UUID, and the computed
  extension. A file uploaded may therefore be given a key such as
  `2024/1/1/0bce8eea-17e0-11ef-b7d4-0242ac120006.png`. See `PhilomenaMedia.Filename.build/1` for
  the actual construction.

  This function does not persist an upload to storage.

  See the module documentation for a complete example.

  ## Example

      @spec analyze_upload(Uploader.schema_or_changeset(), map()) :: Ecto.Changeset.t()
      def analyze_upload(schema, params) do
        Uploader.analyze_upload(schema, "foo", params["foo"], &Schema.foo_changeset/2)
      end

  """
  @spec analyze_upload(
          schema_or_changeset(),
          field_name(),
          Plug.Upload.t(),
          (schema_or_changeset(), map() -> Ecto.Changeset.t())
        ) :: Ecto.Changeset.t()
  def analyze_upload(schema_or_changeset, field_name, upload_parameter, changeset_fn) do
    with {:ok, analysis} <- Analyzers.analyze(upload_parameter),
         analysis <- extra_attributes(analysis, upload_parameter) do
      removed =
        schema_or_changeset
        |> change()
        |> get_field(field(field_name))

      attributes =
        %{
          "name" => analysis.name,
          "width" => analysis.width,
          "height" => analysis.height,
          "size" => analysis.size,
          "orig_size" => analysis.size,
          "format" => analysis.extension,
          "mime_type" => analysis.mime_type,
          "duration" => analysis.duration,
          "aspect_ratio" => analysis.aspect_ratio,
          "orig_sha512_hash" => analysis.sha512,
          "sha512_hash" => analysis.sha512,
          "is_animated" => analysis.animated?
        }
        |> prefix_attributes(field_name)
        |> Map.put(field_name, analysis.new_name)
        |> Map.put(upload_key(field_name), upload_parameter.path)
        |> Map.put(remove_key(field_name), removed)

      changeset_fn.(schema_or_changeset, attributes)
    else
      {:unsupported_mime, mime} ->
        attributes = prefix_attributes(%{"mime_type" => mime}, field_name)
        changeset_fn.(schema_or_changeset, attributes)

      _error ->
        changeset_fn.(schema_or_changeset, %{})
    end
  end

  @doc """
  Writes the file to permanent storage. This should be the second-to-last step
  before completing a file operation.

  The key (location to write the persisted file) is fetched from the schema by `field_name`.
  This is then prefixed with the `file_root` specified by the caller. Finally, the file is
  written to storage.

  See the module documentation for a complete example.

  ## Example

      @spec persist_upload(Schema.t()) :: :ok
      def persist_upload(schema) do
        Uploader.persist_upload(schema, schema_file_root(), "foo")
      end

  """
  @spec persist_upload(schema(), file_root(), field_name()) :: :ok
  def persist_upload(schema, file_root, field_name) do
    source = Map.get(schema, field(upload_key(field_name)))
    dest = Map.get(schema, field(field_name))
    target = Path.join(file_root, dest)

    persist_file(target, source)
  end

  @doc """
  Persist an arbitrary file to storage with the given key.

  > #### Warning {: .warning}
  >
  > This is exposed for schemas which do not store their files at at an offset from a file root,
  > to allow overriding the key. If you do not need to override the key, use
  > `persist_upload/3` instead.

  The key (location to write the persisted file) and the file path to upload are passed through
  to `PhilomenaMedia.Objects.upload/2` without modification. See the definition of that function for
  additional details.

  ## Example

      key = "2024/1/1/5/full.png"
      Uploader.persist_file(key, file_path)

  """
  @spec persist_file(Objects.key(), Path.t()) :: :ok
  def persist_file(key, file_path) do
    Objects.upload(key, file_path)
  end

  @doc """
  Removes the old file from permanent storage. This should be the last step in
  completing a file operation.

  The key (location to write the persisted file) is fetched from the schema by `field_name`.
  This is then prefixed with the `file_root` specified by the caller. Finally, the file is
  purged from storage.

  See the module documentation for a complete example.

  ## Example

      @spec unpersist_old_upload(Schema.t()) :: :ok
      def unpersist_old_upload(schema) do
        Uploader.unpersist_old_upload(schema, schema_file_root(), "foo")
      end

  """
  @spec unpersist_old_upload(schema(), file_root(), field_name()) :: :ok
  def unpersist_old_upload(schema, file_root, field_name) do
    schema
    |> Map.get(field(remove_key(field_name)))
    |> try_remove(file_root)
  end

  defp extra_attributes(analysis, %Plug.Upload{path: path, filename: filename}) do
    {width, height} = analysis.dimensions
    aspect_ratio = aspect_ratio(width, height)

    stat = File.stat!(path)
    sha512 = Sha512.file(path)
    new_name = Filename.build(analysis.extension)

    analysis
    |> Map.put(:size, stat.size)
    |> Map.put(:name, filename)
    |> Map.put(:width, width)
    |> Map.put(:height, height)
    |> Map.put(:sha512, sha512)
    |> Map.put(:new_name, new_name)
    |> Map.put(:aspect_ratio, aspect_ratio)
  end

  defp aspect_ratio(_, 0), do: 0.0
  defp aspect_ratio(w, h), do: w / h

  defp try_remove("", _file_root), do: :ok
  defp try_remove(nil, _file_root), do: :ok

  defp try_remove(file, file_root) do
    Objects.delete(Path.join(file_root, file))
  end

  defp prefix_attributes(map, prefix),
    do: Map.new(map, fn {key, value} -> {"#{prefix}_#{key}", value} end)

  defp upload_key(field_name), do: "uploaded_#{field_name}"

  defp remove_key(field_name), do: "removed_#{field_name}"

  defp field(field_name), do: String.to_existing_atom(field_name)
end
