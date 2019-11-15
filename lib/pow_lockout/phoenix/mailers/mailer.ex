defmodule PowLockout.Phoenix.Mailer do
  @moduledoc false
  alias Plug.Conn
  alias Pow.Phoenix.Mailer.Mail
  alias PowLockout.Phoenix.MailerView

  @spec email_unlock(Conn.t(), map(), binary()) :: Mail.t()
  def email_unlock(conn, user, url) do
    Mail.new(conn, user, {MailerView, :email_unlock}, url: url)
  end
end
