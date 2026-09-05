defmodule PhilomenaWeb.ContentSecurityPolicyPlug do
  import Plug.Conn

  alias PhilomenaWeb.Config
  alias PhilomenaWeb.ContentSecurityPolicy

  @conn_key :csp_sources
  @csp_header "content-security-policy"

  def init(_opts), do: []

  def call(conn, _opts) do
    register_before_send(conn, fn conn ->
      if conn.status == 500 and Config.csp_relax_on_error?() do
        # Allow Plug.Debugger to function in development
        delete_resp_header(conn, @csp_header)
      else
        additions = Map.get(conn.private, @conn_key, %{})

        csp_value =
          conn
          |> ContentSecurityPolicy.conn_policy(additions)
          |> ContentSecurityPolicy.serialize()

        put_resp_header(conn, @csp_header, csp_value)
      end
    end)
  end

  @doc """
  Adds request-specific sources to the CSP for the current request.
  """
  @spec permit_sources(Plug.Conn.t(), %{optional(atom()) => [String.t()]}) :: Plug.Conn.t()
  def permit_sources(conn, additions) do
    sources =
      conn.private
      |> Map.get(@conn_key, %{})
      |> ContentSecurityPolicy.merge_policy(additions)

    put_private(conn, @conn_key, sources)
  end
end
