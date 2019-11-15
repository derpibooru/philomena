defmodule PhilomenaWeb.PowMailer do
  use Pow.Phoenix.Mailer
  alias PhilomenaWeb.Mailer
  alias Philomena.Users.User
  import Bamboo.Email

  def cast(%{user: %User{email: email}, subject: subject, text: text, html: html, assigns: _assigns}) do
    # Build email struct to be used in `process/1`
    new_email(
      to: email,
      from: Application.get_env(:philomena, :mailer_address),
      subject: subject,
      text_body: text,
      html_body: html
    )
  end

  def process(email) do
    email
    |> Mailer.deliver_later()
  end
end