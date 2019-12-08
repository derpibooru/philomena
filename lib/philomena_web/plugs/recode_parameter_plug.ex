defmodule PhilomenaWeb.RecodeParameterPlug do
  def init(opts), do: opts

  def call(conn, [name: name]) do
    fixed_value =
      conn
      |> Map.get(:params)
      |> Map.get(name)
      |> to_string()
      |> URI.encode_www_form()
      |> String.replace("%2B", "+")

    params = Map.put(conn.params, name, fixed_value)

    %{conn | params: params}
  end
end