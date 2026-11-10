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
    conn
    |> maybe_assign_notifications(conn.assigns.actor)
    |> maybe_assign_conversations(conn.assigns.actor)
  end

  defp maybe_assign_notifications(conn, actor) do
    notifications = Notifications.total_unread_count(actor)

    Conn.assign(conn, :notification_count, notifications)
  end

  defp maybe_assign_conversations(conn, %{user: nil}), do: conn

  defp maybe_assign_conversations(conn, actor) do
    case Conversations.unread_conversation_count(actor) do
      {:ok, conversations} -> Conn.assign(conn, :conversation_count, conversations)
      {:error, _reason} -> conn
    end
  end
end
