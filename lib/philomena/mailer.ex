defmodule Philomena.Mailer do
  use Swoosh.Mailer, otp_app: :philomena
  alias Swoosh.Email

  @spec deliver_later(Email.t()) :: {:ok, Email.t()}
  def deliver_later(mail) do
    Task.Supervisor.start_child(Philomena.AsyncEmailSupervisor, fn -> deliver(mail) end)
    {:ok, mail}
  end

  @spec format_message(Email.t()) :: Email.t()
  def format_message(mail) do
    mail
    |> Email.from({"noreply", mailer_address()})
    |> Email.header("Message-ID", rfc2822_message_id())
    |> Email.header("Date", rfc2822_date())
  end

  defp rfc2822_message_id do
    id =
      :crypto.strong_rand_bytes(16)
      |> Base.encode16()
      |> String.downcase()

    "<#{id}.#{mailer_address()}>"
  end

  defp rfc2822_date do
    Calendar.strftime(DateTime.utc_now(), "%a, %-d %b %Y %H:%M:%S %z")
  end

  defp mailer_address do
    Application.get_env(:philomena, :mailer_address)
  end
end
