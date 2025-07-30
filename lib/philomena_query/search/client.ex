defmodule PhilomenaQuery.Search.Client do
  @moduledoc """
  HTTP-level interaction with OpenSearch JSON API.

  Allows two styles of parameters for bodies:
  - map: the map is directly encoded as a JSON object
  - list: each element of the list is encoded as a JSON object and interspersed with newlines.
    This is used by bulk APIs.
  """

  @receive_timeout 30_000

  @type list_or_map :: list() | map()
  @type result :: {:ok, Req.Response.t()} | {:error, Exception.t()}

  @doc """
  HTTP GET
  """
  @spec get(String.t(), list_or_map()) :: result()
  def get(url, body) do
    Req.get(url, encode_options(body))
  end

  @doc """
  HTTP POST
  """
  @spec post(String.t(), list_or_map()) :: result()
  def post(url, body) do
    Req.post(url, encode_options(body))
  end

  @doc """
  HTTP PUT
  """
  @spec put(String.t(), list_or_map()) :: result()
  def put(url, body) do
    Req.put(url, encode_options(body))
  end

  @doc """
  HTTP DELETE
  """
  @spec delete(String.t()) :: result()
  def delete(url) do
    Req.delete(url, encode_options())
  end

  defp encode_body(body) when is_map(body),
    do: JSON.encode_to_iodata!(body)

  defp encode_body(body) when is_list(body),
    do: [Enum.map_intersperse(body, "\n", &JSON.encode_to_iodata!(&1)), "\n"]

  defp encode_options,
    do: [headers: request_headers(), receive_timeout: @receive_timeout]

  defp encode_options(body),
    do: Keyword.merge(encode_options(), body: encode_body(body))

  defp request_headers,
    do: [content_type: "application/json"]
end
