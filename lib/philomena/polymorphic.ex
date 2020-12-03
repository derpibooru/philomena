defmodule Philomena.Polymorphic do
  alias Philomena.Repo
  import Ecto.Query

  @classes %{
    "Channel" => Philomena.Channels.Channel,
    "Comment" => Philomena.Comments.Comment,
    "Commission" => Philomena.Commissions.Commission,
    "Conversation" => Philomena.Conversations.Conversation,
    "DnpEntry" => Philomena.DnpEntries.DnpEntry,
    "Filter" => Philomena.Filters.Filter,
    "Forum" => Philomena.Forums.Forum,
    "Gallery" => Philomena.Galleries.Gallery,
    "Image" => Philomena.Images.Image,
    "LivestreamChannel" => Philomena.Channels.Channel,
    "Post" => Philomena.Posts.Post,
    "Report" => Philomena.Reports.Report,
    "Topic" => Philomena.Topics.Topic,
    "User" => Philomena.Users.User
  }

  @preloads %{
    "Comment" => [:user, image: [tags: :aliases]],
    "Commission" => [:user],
    "Conversation" => [:from, :to],
    "DnpEntry" => [:requesting_user],
    "Gallery" => [:creator],
    "Image" => [:user, tags: :aliases],
    "Post" => [:user, topic: :forum],
    "Topic" => [:forum, :user],
    "Report" => [:user]
  }

  # Deal with Rails polymorphism BS
  def load_polymorphic(structs, associations) when is_list(associations) do
    Enum.reduce(associations, structs, fn asc, acc -> load_polymorphic(acc, asc) end)
  end

  def load_polymorphic(structs, {name, [{id, type}]}) do
    modules_and_ids =
      structs
      |> Enum.group_by(&Map.get(&1, type), &Map.get(&1, id))

    loaded_rows =
      modules_and_ids
      |> Map.new(fn
        {nil, _ids} ->
          {nil, []}

        {type, ids} ->
          pre = Map.get(@preloads, type, [])

          rows =
            @classes[type]
            |> where([m], m.id in ^ids)
            |> preload(^pre)
            |> Repo.all()
            |> Map.new(fn r -> {r.id, r} end)

          {type, rows}
      end)

    structs
    |> Enum.map(fn struct ->
      type = Map.get(struct, type)
      id = Map.get(struct, id)
      row = loaded_rows[type][id]

      %{struct | name => row}
    end)
  end
end
