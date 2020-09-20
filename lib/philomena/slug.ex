defmodule Philomena.Slug do
  # Generates a URL-safe slug from a string by removing nonessential
  # information from it.
  #
  # The process for this is as follows:
  #
  # 1. Remove non-ASCII or non-printable characters.
  #
  # 2. Replace any runs of non-alphanumeric characters that were allowed
  #    through previously with hyphens.
  #
  # 3. Remove any starting or ending hyphens.
  #
  # 4. Convert all characters to their lowercase equivalents.
  #
  # This method makes no guarantee of creating unique slugs for unique inputs.
  # In addition, for certain inputs, it will return empty strings.
  #
  # Example
  #
  #   destructive_slug("Time-Wasting Thread 3.0 (SFW - No Explicit/Grimdark)")
  #   #=> "time-wasting-thread-3-0-sfw-no-explicit-grimdark"
  #
  #   destructive_slug("~`!@#$%^&*()-_=+[]{};:'\" <>,./?")
  #   #=> ""
  #
  @spec destructive_slug(String.t()) :: String.t()
  def destructive_slug(input) when is_binary(input) do
    input
    # 1
    |> String.replace(~r/[^ -~]/, "")
    # 2
    |> String.replace(~r/[^a-zA-Z0-9]+/, "-")
    # 3
    |> String.replace(~r/\A-|-\z/, "")
    # 4
    |> String.downcase()
  end

  def destructive_slug(_input), do: ""

  def slug(string) when is_binary(string) do
    string
    |> String.replace("-", "-dash-")
    |> String.replace("/", "-fwslash-")
    |> String.replace("\\", "-bwslash-")
    |> String.replace(":", "-colon-")
    |> String.replace(".", "-dot-")
    |> String.replace("+", "-plus-")
    |> String.replace(" ", "+")
  end

  def slug(_string), do: ""
end
