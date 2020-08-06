defmodule Philomena.Users.UserNotifier do
  alias Bamboo.Email
  alias Philomena.Mailer

  defp deliver(to, subject, body) do
    email =
      Email.new_email(
        to: to,
        from: mailer_address(),
        subject: subject,
        text_body: body
      )
      |> Email.put_header("Message-ID", gen_message_id())
      |> Email.put_header("Date", gen_timestamp())
      |> Mailer.deliver_later()

    {:ok, email}
  end

  @doc """
  Deliver instructions to confirm account.
  """
  def deliver_confirmation_instructions(user, url) do
    deliver(user.email, "Confirmation instructions for your account", """

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
    deliver(user.email, "Password reset instructions for your account", """

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
    deliver(user.email, "Email update instructions for your account", """

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
    deliver(user.email, "Unlock instructions for your account", """

    ==============================

    Hi #{user.name},

    Your account has been automatically locked due to too many attempts to sign in.

    You can unlock your account by visting the URL below:

    #{url}

    ==============================
    """)
  end

  defp gen_message_id() do
    hostname = Application.get_env(:philomena, Philomena.Mailer)[:hostname]

    [ "<", time32(), ".", rand8(), "@", hostname, ">" ] |> Enum.join("")
  end

  defp time32() do
    System.os_time(:second) |> Integer.to_string() |> Base.encode32()
  end

  defp rand8() do
    :crypto.strong_rand_bytes(64) |> Base.url_encode64() |> binary_part(0, 8)
  end

  defp gen_timestamp() do
    DateTime.utc_now() |> DateTime.to_string()
  end

  defp mailer_address do
    Application.get_env(:philomena, :mailer_address)
  end
end
