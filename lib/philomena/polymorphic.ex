defmodule Philomena.Polymorphic do
  alias Philomena.Repo
  import Ecto.Query

  @classes %{
    "Channel" => Philomena.Channels.Channel,
    "Comment" => Philomena.Comments.Comment,
    "Commission" => Philomena.Commissions.Commission,
    "Conversation" => Philomena.Conversations.Conversation,
    "Filter" => Philomena.Filters.Filter,
    "Forum" => Philomena.Forums.Forum,
    "Gallery" => Philomena.Galleries.Gallery,
    "Image" => Philomena.Images.Image,
    "LivestreamChannel" => Philomena.Channels.Channel,
    "Post" => Philomena.Posts.Post,
    "Topic" => Philomena.Topics.Topic,
    "User" => Philomena.Users.User
  }

  # Deal with Rails polymorphism BS
  def load_polymorphic(structs, associations) when is_list(associations) do
    Enum.reduce(associations, structs, fn asc, acc -> load_polymorphic(acc, asc) end)
  end

  def load_polymorphic(structs, {name, {id, type}}) do
    modules_and_ids =
      structs
      |> Enum.group_by(& &1[type], & &1[id])

    loaded_rows =
      modules_and_ids
      |> Map.new(fn
        {nil, _ids} ->
          {nil, []}

        {type, ids} ->
          rows =
            @classes[type]
            |> where([m], m.id in ^ids)
            |> Repo.all()
            |> Map.new(fn r -> {r.id, r} end)

          {type, rows}
      end)

    structs
    |> Enum.map(fn struct ->
      row = loaded_rows[struct[type]][struct[id]]

      %{struct | name => row}
    end)
  end
end