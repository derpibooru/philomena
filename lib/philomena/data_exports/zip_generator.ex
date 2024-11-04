defmodule Philomena.DataExports.ZipGenerator do
  @moduledoc """
  ZIP file generator for an export.
  """

  alias Philomena.Native

  @doc """
  Write the ZIP file for the given aggregate data.

  Expects a list of 2-tuples, with the first element being the name of the
  file to generate, and the second element being a stream which generates the
  binary contents of the file.
  """
  @spec generate(Path.t(), Enumerable.t()) :: :ok | atom()
  def generate(filename, aggregate) do
    case Native.zip_open_writer(filename) do
      {:ok, zip} ->
        stream_aggregate(zip, aggregate)

      error ->
        error
    end
  end

  @spec stream_aggregate(reference(), Enumerable.t()) :: {:ok, reference()} | :error
  defp stream_aggregate(zip, aggregate) do
    aggregate
    |> Enum.reduce_while(:ok, fn {name, content_stream}, _ ->
      with :ok <- Native.zip_start_file(zip, name),
           :ok <- stream_file_data(zip, content_stream) do
        {:cont, :ok}
      else
        error ->
          {:halt, error}
      end
    end)
    |> case do
      :ok ->
        Native.zip_finish(zip)

      error ->
        error
    end
  end

  @spec stream_file_data(reference(), Enumerable.t(iodata())) :: :ok | :error
  defp stream_file_data(zip, content_stream) do
    Enum.reduce_while(content_stream, :ok, fn iodata, _ ->
      case Native.zip_write(zip, IO.iodata_to_binary(iodata)) do
        :ok -> {:cont, :ok}
        error -> {:halt, error}
      end
    end)
  end
end
