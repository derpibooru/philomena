defmodule Camo.Image do
  def image_url(input) do
    if camo_host() == nil or camo_host() == "" do
      input
    else
      %{host: host} = URI.parse(input)

      if !host or String.ends_with?(host, cdn_host()) do
        input
      else
        camo_digest = :crypto.hmac(:sha, camo_key(), input) |> Base.encode16(case: :lower)

        camo_uri = %URI{
          host: camo_host(),
          path: "/" <> camo_digest,
          query: URI.encode_query(url: input),
          scheme: "https"
        }

        URI.to_string(camo_uri)
      end
    end
  end

  defp cdn_host do
    Application.get_env(:philomena, :cdn_host)
  end

  defp camo_key do
    Application.get_env(:philomena, :camo_key)
  end

  defp camo_host do
    Application.get_env(:philomena, :camo_host)
  end
end
