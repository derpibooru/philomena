defmodule PhilomenaWeb.ModerationLogPlug do
  @moduledoc """
  This plug writes moderation logs.
  ## Example

      plug PhilomenaWeb.ModerationLogPlug, [details: &log_details/2]
  """

  @controller_regex ~r/PhilomenaWeb\.([\w\.]+)Controller\z/

  alias Plug.Conn
  alias Phoenix.Controller
  alias Philomena.ModerationLogs

  @doc false
  @spec init(any()) :: any()
  def init(opts), do: opts

  @type log_details :: %{subject_path: String.t(), body: String.t()}
  @type details_func :: (Plug.Conn.t(), atom(), any() -> log_details())
  @type call_opts :: [details: details_func, data: any()]

  @doc false
  @spec call(Conn.t(), call_opts) :: Conn.t()
  def call(conn, opts) do
    details_func = Keyword.fetch!(opts, :details)
    userdata = Keyword.get(opts, :data, nil)

    user = conn.assigns.current_user
    action = Controller.action_name(conn)

    %{subject_path: subject_path, body: body} = details_func.(conn, action, userdata)

    mod = Controller.controller_module(conn)
    [mod_name] = Regex.run(@controller_regex, to_string(mod), capture: :all_but_first)
    type = "#{mod_name}:#{action}"

    ModerationLogs.create_moderation_log(user, type, subject_path, body)

    conn
  end

  @doc false
  @spec moderation_log(Conn.t(), call_opts()) :: Conn.t()
  def moderation_log(conn, opts), do: call(conn, opts)
end
