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
    Email.from(mail, {"noreply", mailer_address()})
  end

  defp mailer_address do
    Application.get_env(:philomena, :mailer_address)
  end
end
