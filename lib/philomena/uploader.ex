defmodule Philomena.Uploader do
  @moduledoc """
  Upload and processing callback logic for image files.
  """

  alias Philomena.Filename
  alias Philomena.Analyzers
  alias Philomena.Objects
  alias Philomena.Sha512
  import Ecto.Changeset

  @doc """
  Performs analysis of the passed Plug.Upload, and invokes a changeset
  callback on the model or changeset passed in with attributes set on
  the field_name.
  """
  @spec analyze_upload(any(), String.t(), Plug.Upload.t(), (any(), map() -> Ecto.Changeset.t())) ::
          Ecto.Changeset.t()
  def analyze_upload(model_or_changeset, field_name, upload_parameter, changeset_fn) do
    with {:ok, analysis} <- Analyzers.analyze(upload_parameter),
         analysis <- extra_attributes(analysis, upload_parameter) do
      removed =
        model_or_changeset
        |> change()
        |> get_field(field(field_name))

      attributes =
        %{
          "name" => analysis.name,
          "width" => analysis.width,
          "height" => analysis.height,
          "size" => analysis.size,
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

      changeset_fn.(model_or_changeset, attributes)
    else
      {:unsupported_mime, mime} ->
        attributes = prefix_attributes(%{"mime_type" => mime}, field_name)
        changeset_fn.(model_or_changeset, attributes)

      _error ->
        changeset_fn.(model_or_changeset, %{})
    end
  end

  @doc """
  Writes the file to permanent storage. This should be the second-to-last step
  in the transaction.
  """
  @spec persist_upload(any(), String.t(), String.t()) :: any()
  def persist_upload(model, file_root, field_name) do
    source = Map.get(model, field(upload_key(field_name)))
    dest = Map.get(model, field(field_name))
    target = Path.join(file_root, dest)

    persist_file(target, source)
  end

  @doc """
  Persist an arbitrary file to storage at the given path with the correct
  content type and permissions.
  """
  def persist_file(path, file) do
    Objects.upload(path, file)
  end

  @doc """
  Removes the old file from permanent storage. This should be the last step in
  the transaction.
  """
  @spec unpersist_old_upload(any(), String.t(), String.t()) :: any()
  def unpersist_old_upload(model, file_root, field_name) do
    model
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

  defp try_remove("", _file_root), do: nil
  defp try_remove(nil, _file_root), do: nil

  defp try_remove(file, file_root) do
    Objects.delete(Path.join(file_root, file))
  end

  defp prefix_attributes(map, prefix),
    do: Map.new(map, fn {key, value} -> {"#{prefix}_#{key}", value} end)

  defp upload_key(field_name), do: "uploaded_#{field_name}"

  defp remove_key(field_name), do: "removed_#{field_name}"

  defp field(field_name), do: String.to_existing_atom(field_name)
end
