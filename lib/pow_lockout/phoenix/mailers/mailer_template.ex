defmodule PowLockout.Phoenix.MailerTemplate do
  @moduledoc false
  use Pow.Phoenix.Mailer.Template

  template :email_unlock,
  "Unlock your account",
  """
  Hi,

  Your account has been automatically disabled due to too many unsuccessful
  attempts to sign in.

  Please use the following link to unlock your account:

  <%= @url %>
  """,
  """
  <%= content_tag(:h3, "Hi,") %>
  <%= content_tag(:p, "Your account has been automatically disabled due to too many unsuccessful attempts to sign in.") %>
  <%= content_tag(:p, "Please use the following link to unlock your account:") %>
  <%= content_tag(:p, link(@url, to: @url)) %>
  """
end
