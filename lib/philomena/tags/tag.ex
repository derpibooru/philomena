defmodule Philomena.Tags.Tag do
  use Ecto.Schema
  import Ecto.Changeset
  import Ecto.Query

  alias Philomena.Channels.Channel
  alias Philomena.DnpEntries.DnpEntry
  alias Philomena.ArtistLinks.ArtistLink
  alias Philomena.Tags.Tag
  alias Philomena.Slug
  alias Philomena.Repo

  @namespaces [
    "artist",
    "art pack",
    "ask",
    "blog",
    "colorist",
    "comic",
    "commissioner",
    "editor",
    "fanfic",
    "generator",
    "oc",
    "parent",
    "parents",
    "photographer",
    "prompter",
    "series",
    "species",
    "spoiler",
    "video"
  ]

  @namespace_categories %{
    "artist" => "origin",
    "art pack" => "content-fanmade",
    "colorist" => "origin",
    "comic" => "content-fanmade",
    "editor" => "origin",
    "fanfic" => "content-fanmade",
    "generator" => "origin",
    "oc" => "oc",
    "photographer" => "origin",
    "prompter" => "origin",
    "series" => "content-fanmade",
    "spoiler" => "spoiler",
    "video" => "content-fanmade"
  }

  @underscore_safe_namespaces [
    "artist:",
    "colorist:",
    "commissioner:",
    "editor:",
    "generator:",
    "oc:",
    "photographer:",
    "prompter:"
  ]

  @derive {Phoenix.Param, key: :slug}

  schema "tags" do
    belongs_to :aliased_tag, Tag, source: :aliased_tag_id, on_replace: :nilify
    has_many :aliases, Tag, foreign_key: :aliased_tag_id

    has_many :channels, Channel, foreign_key: :associated_artist_tag_id

    many_to_many :implied_tags, Tag,
      join_through: "tags_implied_tags",
      join_keys: [tag_id: :id, implied_tag_id: :id],
      on_replace: :delete

    many_to_many :implied_by_tags, Tag,
      join_through: "tags_implied_tags",
      join_keys: [implied_tag_id: :id, tag_id: :id]

    has_many :verified_links, ArtistLink, where: [aasm_state: "verified"]
    has_many :public_links, ArtistLink, where: [public: true, aasm_state: "verified"]
    has_many :hidden_links, ArtistLink, where: [public: false, aasm_state: "verified"]
    has_many :dnp_entries, DnpEntry, where: [aasm_state: "listed"]

    field :slug, :string
    field :name, :string
    field :category, :string
    field :images_count, :integer, default: 0
    field :description, :string, default: ""
    field :short_description, :string
    field :namespace, :string
    field :name_in_namespace, :string
    field :image, :string
    field :image_format, :string
    field :image_mime_type, :string
    field :mod_notes, :string

    field :uploaded_image, :string, virtual: true
    field :removed_image, :string, virtual: true

    field :implied_tag_list, :string, virtual: true

    timestamps(inserted_at: :created_at, type: :utc_datetime)
  end

  @doc false
  def changeset(tag, attrs) do
    tag
    |> cast(attrs, [:category, :description, :short_description, :mod_notes])
    |> put_change(:implied_tag_list, Enum.map_join(tag.implied_tags, ",", & &1.name))
    |> validate_required([])
  end

  def changeset(tag, attrs, implied_tags) do
    tag
    |> cast(attrs, [:category, :description, :short_description, :mod_notes])
    |> put_assoc(:implied_tags, implied_tags)
    |> validate_required([])
  end

  def image_changeset(tag, attrs) do
    tag
    |> cast(attrs, [:image, :image_format, :image_mime_type, :uploaded_image])
    |> validate_required([:image, :image_format, :image_mime_type])
    |> validate_inclusion(:image_mime_type, ~W(image/gif image/jpeg image/png image/svg+xml))
  end

  def remove_image_changeset(tag) do
    change(tag)
    |> put_change(:removed_image, tag.image)
    |> put_change(:image, nil)
  end

  def alias_changeset(tag, target_tag) do
    change(tag)
    |> put_assoc(:aliased_tag, target_tag)
    |> validate_required([:aliased_tag])
    |> validate_not_aliased_to_self()
    |> validate_alias_not_transitive()
    |> validate_incoming_aliases()
  end

  def unalias_changeset(tag) do
    change(tag, aliased_tag_id: nil)
  end

  def creation_changeset(tag, attrs) do
    tag
    |> cast(attrs, [:name])
    |> validate_required([:name])
    |> put_slug()
    |> put_name_and_namespace()
    |> put_namespace_category()
  end

  def parse_tag_list(list) do
    list
    |> to_string()
    |> String.split(",")
    |> Enum.map(&clean_tag_name/1)
    |> Enum.reject(&("" == &1))
    |> Enum.uniq()
  end

  def display_order(tags) do
    tags
    |> Enum.sort_by(
      &{
        &1.category != "error",
        &1.category != "rating",
        &1.category != "origin",
        &1.category != "character",
        &1.category != "oc",
        &1.category != "species",
        &1.category != "body-type",
        &1.category != "content-fanmade",
        &1.category != "content-official",
        &1.category != "spoiler",
        &1.name
      }
    )
  end

  def categories do
    [
      "error",
      "rating",
      "origin",
      "character",
      "oc",
      "species",
      "body-type",
      "content-fanmade",
      "content-official",
      "spoiler"
    ]
  end

  def clean_tag_name(name) do
    # Downcase, replace extra runs of spaces, replace unicode quotes
    # with ascii quotes, trim space from end
    name
    |> String.downcase()
    |> String.replace(
      ~r/[[:space:]\x{00a0}\x{1680}\x{180e}\x{2000}-\x{200f}\x{202f}\x{205f}\x{3000}\x{feff}]+/u,
      " "
    )
    |> String.replace(~r/[\x{00b4}\x{2018}\x{2019}\x{201a}\x{201b}\x{2032}]/u, "'")
    |> String.replace(~r/[\x{201c}\x{201d}\x{201e}\x{201f}\x{2033}]/u, "\"")
    |> clean_tag_namespace()
    |> ununderscore()
    |> String.trim()
    |> String.replace(~r/ +/, " ")
  end

  defp clean_tag_namespace(name) do
    # Remove extra spaces after the colon in a namespace
    # (artist:, oc:, etc.)
    name
    |> String.split(":", parts: 2)
    |> Enum.map(&String.trim/1)
    |> join_namespace_parts(name)
  end

  defp join_namespace_parts([_name], original_name),
    do: original_name

  defp join_namespace_parts([namespace, name], _original_name) when namespace in @namespaces,
    do: namespace <> ":" <> name

  defp join_namespace_parts([_namespace, _name], original_name),
    do: original_name

  defp ununderscore(name) do
    if String.starts_with?(name, @underscore_safe_namespaces) do
      name
    else
      String.replace(name, "_", " ")
    end
  end

  defp put_slug(changeset) do
    slug =
      changeset
      |> get_field(:name)
      |> to_string()
      |> Slug.slug()

    changeset
    |> change(slug: slug)
  end

  defp put_name_and_namespace(changeset) do
    {namespace, name_in_namespace} =
      changeset
      |> get_field(:name)
      |> to_string()
      |> extract_name_and_namespace()

    changeset
    |> change(namespace: namespace)
    |> change(name_in_namespace: name_in_namespace)
  end

  defp extract_name_and_namespace(name) do
    case String.split(name, ":", parts: 2) do
      [namespace, name_in_namespace] when namespace in @namespaces ->
        {namespace, name_in_namespace}

      _value ->
        {nil, name}
    end
  end

  defp put_namespace_category(changeset) do
    namespace = changeset |> get_field(:namespace)

    case @namespace_categories[namespace] do
      nil -> changeset
      category -> change(changeset, category: category)
    end
  end

  defp validate_not_aliased_to_self(changeset) do
    aliased_tag = get_field(changeset, :aliased_tag)
    id = get_field(changeset, :id)

    case aliased_tag do
      %{id: ^id} ->
        add_error(changeset, :aliased_tag, "is the same tag as the source")

      _tag ->
        changeset
    end
  end

  defp validate_alias_not_transitive(changeset) do
    case get_field(changeset, :aliased_tag) do
      %{aliased_tag_id: tag} when not is_nil(tag) ->
        add_error(
          changeset,
          :aliased_tag,
          "is itself aliased and would create a transitive alias"
        )

      _tag ->
        changeset
    end
  end

  defp validate_incoming_aliases(changeset) do
    id = get_field(changeset, :id)

    count =
      Tag
      |> where(aliased_tag_id: ^id)
      |> Repo.aggregate(:count, :id)

    if count > 0 do
      add_error(changeset, :tag, "has incoming aliases and cannot be aliased")
    else
      changeset
    end
  end
end
