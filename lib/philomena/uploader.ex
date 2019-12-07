defmodule Philomena.Uploader do
  @moduledoc """
  Upload and processing callback logic for image files.
  """

  alias Philomena.Filename
  alias Philomena.Analyzers
  alias Philomena.Sha512

  @doc """
  Performs analysis of the passed Plug.Upload, and invokes a changeset
  callback on the model or changeset passed in with attributes set on
  the field_name.
  """
  @spec analyze_upload(any(), String.t(), Plug.Upload.t(), (any(), map() -> Ecto.Changeset.t())) :: Ecto.Changeset.t()
  def analyze_upload(model_or_changeset, field_name, upload_parameter, changeset_fn) do
    with {:ok, analysis} <- Analyzers.analyze(upload_parameter),
         analysis <- extra_attributes(analysis, upload_parameter)
    do
      attributes =
        %{
          "name"             => analysis.name,
          "width"            => analysis.width,
          "height"           => analysis.height,
          "size"             => analysis.size,
          "format"           => analysis.extension,
          "mime_type"        => analysis.mime_type,
          "aspect_ratio"     => analysis.aspect_ratio,
          "orig_sha512_hash" => analysis.sha512,
          "sha512_hash"      => analysis.sha512,
          "is_animated"      => analysis.animated?
        }
        |> prefix_attributes(field_name)
        |> Map.put(field_name, analysis.new_name)
        |> Map.put(upload_key(field_name), upload_parameter.path)

      changeset_fn.(model_or_changeset, attributes)
    else
      _error ->
        changeset_fn.(model_or_changeset, %{})
    end
  end

  @doc """
  Writes the file to permanent storage. This should be the last step in the
  transaction.
  """
  @spec persist_upload(any(), String.t(), String.t()) :: any()
  def persist_upload(model, file_root, field_name) do
    source = Map.get(model, String.to_existing_atom(upload_key(field_name)))
    dest   = Map.get(model, String.to_existing_atom(field_name))
    target = Path.join(file_root, dest)
    dir    = Path.dirname(target)

    # Create the target directory if it doesn't exist yet,
    # then write the file.
    File.mkdir_p!(dir)
    File.cp!(source, target)
  end

  defp extra_attributes(analysis, %Plug.Upload{path: path, filename: filename}) do
    {width, height} = analysis.dimensions
    aspect_ratio    = aspect_ratio(width, height)

    stat     = File.stat!(path)
    sha512   = Sha512.file(path)
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

  defp prefix_attributes(map, prefix),
    do: Map.new(map, fn {key, value} -> {"#{prefix}_#{key}", value} end)

  defp upload_key(field_name), do: "uploaded_#{field_name}"
end