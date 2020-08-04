defmodule PhilomenaWeb.NotificationCountPlug do
  @moduledoc """
  This plug stores the current notification count.

  ## Example

      plug PhilomenaWeb.NotificationCountPlug
  """

  alias Plug.Conn
  alias Philomena.Conversations
  alias Philomena.Notifications

  @doc false
  @spec init(any()) :: any()
  def init(opts), do: opts

  @doc false
  @spec call(Plug.Conn.t()) :: Plug.Conn.t()
  def call(conn), do: call(conn, nil)

  @doc false
  @spec call(Plug.Conn.t(), any()) :: Plug.Conn.t()
  def call(conn, _opts) do
    user = conn.assigns.current_user

    conn
    |> maybe_assign_notifications(user)
    |> maybe_assign_conversations(user)
  end

  defp maybe_assign_notifications(conn, nil), do: conn

  defp maybe_assign_notifications(conn, user) do
    notifications = Notifications.count_unread_notifications(user)

    Conn.assign(conn, :notification_count, notifications)
  end

  defp maybe_assign_conversations(conn, nil), do: conn

  defp maybe_assign_conversations(conn, user) do
    conversations = Conversations.count_unread_conversations(user)

    Conn.assign(conn, :conversation_count, conversations)
  end
end
