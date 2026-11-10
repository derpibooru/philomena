defmodule PhilomenaMedia.Remote do
  @doc """
  Out-of-process replacement for `System.cmd/2` that calls the requested
  command elsewhere, translating file accesses, and returns the result.
  """
  def cmd(command, args) do
    :ok = Philomena.Native.async_process_command(mediaproc_addr(), command, args)

    receive do
      {:command_reply, command_reply} ->
        {command_reply.stdout, command_reply.status}
    end
  end

  @doc """
  Gets the raw, uncorrected MIME type of a file.
  """
  @spec get_mime(Path.t()) :: {:ok, String.t()} | :error
  def get_mime(path) do
    :ok = Philomena.Native.async_get_mime(mediaproc_addr(), path)

    receive do
      {:mime_reply, mime_reply} ->
        mime_reply
    end
  end

  defp mediaproc_addr do
    Application.get_env(:philomena, :mediaproc_addr)
  end
end
