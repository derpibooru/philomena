defmodule PhilomenaWeb.AuthorizedReporterPlug do
  @moduledoc """
  Verifies that a user is allowed to submit Reports.
  Effectively should end up checking the user is logged in.

  ## Example

      plug PhilomenaWeb.AuthorizedReporterPlug when action in [:new, :create]
  """

  alias Canada.Can

  alias Phoenix.Controller
  alias Philomena.Reports.Report
  alias PhilomenaWeb.NotAuthorizedPlug

  alias Plug.Conn

  @spec init(any()) :: any()
  def init(opts), do: opts

  @spec call(Conn.t()) :: Conn.t()
  def call(conn), do: call(conn, nil)

  @spec call(Conn.t(), any()) :: Conn.t()
  def call(conn, _opts) do
    case Can.can?(conn.assigns.current_user, Controller.action_name(conn), Report) do
      true -> conn
      _false -> NotAuthorizedPlug.call(conn)
    end
  end
end

