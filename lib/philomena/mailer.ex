defmodule Philomena.Mailer do
  use Swoosh.Mailer, otp_app: :philomena

  @spec deliver_later(Swoosh.Email.t()) :: {:ok, Swoosh.Email.t()}
  def deliver_later(mail) do
    Task.Supervisor.start_child(Philomena.AsyncEmailSupervisor, fn -> deliver(mail) end)
    {:ok, mail}
  end
end
