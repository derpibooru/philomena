defmodule PhilomenaWeb.MapParameterPlug do
  # A bunch of crappy behaviors all interacting to create a
  # symphony of failure:
  #
  # 1.) Router helpers do not strip nil query parameters.
  #     iex> Routes.gallery_path(conn, :index, gallery: nil)
  #     "/galleries?gallery="
  #
  # 2.) Pagination always sets the parameter in the route in order
  #     to preserve the query across multiple pages
  #
  # 3.) When received by the router, an empty param is treated as
  #     an empty string instead of nil
  #
  # 4.) Phoenix.HTML.Form.form_for/2 raises an error if you try to
  #     use it on a conn object which is a string instead of a map
  #     (or nil)

  @spec init(Keyword.t()) :: Keyword.t()
  def init(opts) do
    opts
  end

  @spec call(Plug.Conn.t(), Keyword.t()) :: Plug.Conn.t()
  def call(conn, opts) do
    param = Keyword.fetch!(opts, :param)
    value = conn.params[param]

    cond do
      is_map(value) ->
        conn

      true ->
        params = Map.delete(conn.params, param)

        Map.put(conn, :params, params)
    end
  end
end
