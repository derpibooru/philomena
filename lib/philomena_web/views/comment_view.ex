defmodule PhilomenaWeb.CommentView do
  use PhilomenaWeb, :view

  def link_to_ip(ip) do
    if ip do
      ip
    else
      "N/A"
    end
  end

  def link_to_fingerprint(fp) do
    if fp do
      fp |> String.slice(0..6)
    else
      "N/A"
    end
  end
end
