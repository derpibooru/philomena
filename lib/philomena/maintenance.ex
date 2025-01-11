defmodule Philomena.Maintenance do
  @moduledoc """
  Functions related to online and offline maintenance tasks.
  """

  @typedoc "Progress from a stream job."
  @type progress_report :: %{
          curr: integer(),
          rate: number(),
          remaining_time: number()
        }

  @doc """
  Periodically stream progress reports for a stream task that produces a range
  of integers between `min` and `max`, estimating the rate of progress and time
  remaining.
  """
  @spec stream_progress(
          id_stream :: Enumerable.t({:ok, integer()}),
          min :: integer(),
          max :: integer(),
          report_period :: number()
        ) :: Enumerable.t(progress_report())
  def stream_progress(id_stream, min, max, report_period \\ 1.0) do
    # Reference point for comparison during the stream.
    begin = now()

    # Estimate progress counters based on how many objects have been
    # processed since the initial reference point.
    create_report = fn state, curr_id ->
      curr_rate = (curr_id - min) / max(now() - begin, 1)
      remaining_time = (max - curr_id) / max(curr_rate, 1)

      %{
        state: state,
        curr: curr_id,
        rate: round(curr_rate),
        remaining_time: remaining_time
      }
    end

    # Convert input items received after every period elapses into
    # a report, then concatenate an additional report after all items
    # are processed.
    id_stream
    |> Stream.transform(begin, fn {:ok, curr_id}, prev_time ->
      curr_time = now()

      if curr_time - prev_time > report_period do
        {[create_report.(:in_progress, curr_id)], curr_time}
      else
        {[], prev_time}
      end
    end)
    |> Stream.concat(Stream.map([[]], fn _ -> create_report.(:done, max) end))
  end

  @doc """
  Write progress reports to the console for a stream task that produces a range
  of integers between `min` and `max`, estimating the rate of progress and time
  remaining.
  """
  @spec log_progress(
          id_stream :: Enumerable.t({:ok, integer()}),
          label :: String.t(),
          min :: integer(),
          max :: integer(),
          report_period :: number()
        ) :: :ok
  def log_progress(id_stream, label, min, max, report_period \\ 1.0) do
    id_stream
    |> stream_progress(min, max, report_period)
    |> Enum.each(fn p ->
      # Clear line
      IO.write("\e[2K\r")

      # Newline on report depends on whether stream is finished
      case p.state do
        :in_progress ->
          eta = format_eta(p.remaining_time)

          IO.write("#{label}: #{p.curr}/#{max} [#{p.rate}/sec], ETA: #{eta}")

        :done ->
          IO.puts("#{label}: #{p.curr}/#{max} [#{p.rate}/sec], done.")
      end
    end)
  end

  @spec format_eta(number()) :: String.t()
  defp format_eta(remaining_time) do
    seconds = round(remaining_time)
    minutes = div(seconds, 60)
    hours = div(minutes, 60)

    cond do
      seconds < 45 -> "about #{seconds} second(s)"
      seconds < 90 -> "about a minute"
      minutes < 45 -> "about #{minutes} minute(s)"
      true -> "about #{hours} hour(s)"
    end
  end

  @spec now() :: float()
  defp now do
    :erlang.system_time(:microsecond) / 1_000_000
  end
end
