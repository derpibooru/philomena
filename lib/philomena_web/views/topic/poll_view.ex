defmodule PhilomenaWeb.Topic.PollView do
  use PhilomenaWeb, :view

  def ranked_options(poll) do
    poll.options
    |> Enum.sort_by(&{-&1.vote_count, &1.id})
  end

  def winning_option(poll) do
    poll
    |> ranked_options()
    |> Enum.at(0)
  end

  def active?(poll) do
    DateTime.diff(poll.active_until, DateTime.utc_now()) > 0
  end

  def require_answer?(%{vote_method: vote_method}), do: vote_method == "single"

  def input_type(%{vote_method: "single"}), do: "radio"
  def input_type(_poll), do: "checkbox"

  def input_name(_poll), do: "poll[option_ids][]"

  def percent_of_total(_option, %{total_votes: 0}), do: "0%"

  def percent_of_total(%{vote_count: vote_count}, %{total_votes: total_votes}) do
    :io_lib.format("~.2f%", [vote_count / total_votes * 100])
  end

  def option_class(%{id: option_id}, %{id: option_id}, true), do: "poll-option-top"
  def option_class(_option, _top_option, _winners?), do: nil

  def poll_bar_class(%{id: option_id}, %{id: option_id}, true),
    do: "poll-bar__fill poll-bar__fill--top"

  def poll_bar_class(_option, _top_option, _winners?), do: "poll-bar__fill"
end
