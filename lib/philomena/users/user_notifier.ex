defmodule Philomena.Users.UserNotifier do
  alias Swoosh.Email
  alias Philomena.Mailer

  defp deliver(name, address, subject, body) do
    Email.new(
      to: {name, address},
      from: {"noreply", mailer_address()},
      subject: subject,
      text_body: body
    )
    |> Email.header("Message-ID", message_id())
    |> Mailer.deliver_later()
  end

  defp message_id do
    id =
      :crypto.strong_rand_bytes(16)
      |> Base.encode16()
      |> String.downcase()

    "<#{id}.#{mailer_address()}>"
  end

  defp mailer_address do
    Application.get_env(:philomena, :mailer_address)
  end

  @doc """
  Deliver instructions to confirm account.
  """
  def deliver_confirmation_instructions(user, url) do
    deliver(user.name, user.email, "Confirmation instructions for your account", """

    ==============================

    Hi #{user.name},

    You can confirm your account by visiting the URL below:

    #{url}

    If you didn't create an account with us, please ignore this.

    ==============================
    """)
  end

  @doc """
  Deliver instructions to reset password for an account.
  """
  def deliver_reset_password_instructions(user, url) do
    deliver(user.name, user.email, "Password reset instructions for your account", """

    ==============================

    Hi #{user.name},

    You can reset your password by visiting the URL below:

    #{url}

    If you didn't request this change, please ignore this.

    ==============================
    """)
  end

  @doc """
  Deliver instructions to update an account email.
  """
  def deliver_update_email_instructions(user, url) do
    deliver(user.name, user.email, "Email update instructions for your account", """

    ==============================

    Hi #{user.name},

    You can change your email by visiting the URL below:

    #{url}

    If you didn't request this change, please ignore this.

    ==============================
    """)
  end

  @doc """
  Deliver instructions to unlock an account.
  """
  def deliver_unlock_instructions(user, url) do
    deliver(user.name, user.email, "Unlock instructions for your account", """

    ==============================

    Hi #{user.name},

    Your account has been automatically locked due to too many attempts to sign in.

    You can unlock your account by visiting the URL below:

    #{url}

    ==============================
    """)
  end
end
