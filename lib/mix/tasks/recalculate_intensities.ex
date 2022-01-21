defmodule Mix.Tasks.RecalculateIntensities do
  use Mix.Task

  alias Philomena.Images.{Image, Thumbnailer}
  alias Philomena.ImageIntensities.ImageIntensity
  alias Philomena.Batch
  alias Philomena.Repo

  import Ecto.Query

  @shortdoc "Recalculates all intensities for reverse search."
  @requirements ["app.start"]
  @impl Mix.Task
  def run(_args) do
    Batch.record_batches(Image, fn batch ->
      batch
      |> Stream.with_index()
      |> Stream.each(fn {image, i} ->
        image_file =
          cond do
            image.image_mime_type in ["image/png", "image/jpeg"] ->
              Thumbnailer.image_file(image)

            true ->
              Path.join(Thumbnailer.image_thumb_dir(image), "rendered.png")
          end

        case System.cmd("image-intensities", [image_file]) do
          {output, 0} ->
            [nw, ne, sw, se] =
              output
              |> String.trim()
              |> String.split("\t")
              |> Enum.map(&String.to_float/1)

            ImageIntensity
            |> where(image_id: ^image.id)
            |> Repo.update_all(set: [nw: nw, ne: ne, sw: sw, se: se])

          _ ->
            :err
        end

        if rem(i, 100) == 0 do
          IO.write("\r#{image.id}")
        end
      end)
      |> Stream.run()
    end)

    IO.puts("\nDone")
  end
end
