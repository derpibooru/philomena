defmodule Philomena.ArtistLinks.AutomaticVerifier do
  def check_link(artist_link, recheck_time) do
    artist_link.uri
    |> Philomena.Http.get()
    |> contains_verification_code?(artist_link.verification_code)
    |> case do
      true ->
        %{next_check_at: nil, aasm_state: "link_verified"}

      false ->
        %{next_check_at: recheck_time}
    end
  end

  defp contains_verification_code?({:ok, %Tesla.Env{body: body, status: 200}}, code) do
    String.contains?(body, code)
  end

  defp contains_verification_code?(_response, _code) do
    false
  end
end
