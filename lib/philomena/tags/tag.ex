defmodule Philomena.Tags.Tag do
  use Ecto.Schema
  import Ecto.Changeset

  alias Philomena.Channels.Channel
  alias Philomena.DnpEntries.DnpEntry
  alias Philomena.ArtistLinks.ArtistLink
  alias Philomena.Tags.Tag
  alias Philomena.Slug

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
    "oc",
    "parent",
    "parents",
    "photographer",
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
    "oc" => "oc",
    "photographer" => "origin",
    "series" => "content-fanmade",
    "spoiler" => "spoiler",
    "video" => "content-fanmade"
  }

  @underscore_safe_namespaces [
    "artist:",
    "colorist:",
    "commissioner:",
    "editor:",
    "oc:",
    "photographer:"
  ]

  # Must match the tags_name_length_check constraint in the database,
  # which counts bytes (octet_length). 255 is the largest length the
  # autocomplete binary format can encode (uint8 name_length).
  @name_length_limit 255

  def name_length_limit, do: @name_length_limit

  @derive {Phoenix.Param, key: :slug}

  @type t :: %__MODULE__{}

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
    field :target_tag, :string, virtual: true

    timestamps(inserted_at: :created_at, type: :utc_datetime)
  end

  @doc false
  def insert_fields do
    [
      :slug,
      :name,
      :category,
      :images_count,
      :description,
      :short_description,
      :namespace,
      :name_in_namespace,
      :image,
      :image_format,
      :image_mime_type,
      :mod_notes
    ]
  end

  @doc false
  def changeset(tag, attrs \\ %{}) do
    tag
    |> cast(attrs, [:category, :description, :short_description, :mod_notes, :implied_tag_list])
    |> maybe_put_implied_tag_list(tag)
    |> validate_required([])
    |> validate_inclusion(:category, categories())
  end

  def changeset(tag, attrs, implied_tags) do
    tag
    |> cast(attrs, [:category, :description, :short_description, :mod_notes, :implied_tag_list])
    |> put_assoc(:implied_tags, implied_tags)
    |> validate_no_aliased_implied_tags(implied_tags)
    |> validate_required([])
    |> validate_inclusion(:category, categories())
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

  def implication_form_changeset(tag, attrs \\ %{}) do
    cast(tag, attrs, [:implied_tag_list])
  end

  def alias_form_changeset(tag, attrs \\ %{}) do
    tag
    |> cast(attrs, [:target_tag])
    |> update_change(:target_tag, &clean_tag_name/1)
    |> validate_required(:target_tag)
  end

  def alias_changeset(tag, target_tag, incoming_aliases?, implied_by_tags?) do
    tag
    |> change()
    |> validate_not_aliased()
    |> put_assoc(:aliased_tag, target_tag)
    |> validate_required(:aliased_tag, message: "does not exist")
    |> validate_not_aliased_to_self()
    |> validate_alias_not_transitive()
    |> validate_incoming_aliases(incoming_aliases?)
    |> validate_implied_by_tags(implied_by_tags?)
  end

  def unalias_changeset(tag) do
    tag
    |> change()
    |> validate_aliased()
    |> put_change(:aliased_tag_id, nil)
  end

  defp validate_not_aliased(changeset) do
    if get_field(changeset, :aliased_tag_id) do
      add_error(changeset, :aliased_tag, "is already aliased")
    else
      changeset
    end
  end

  defp validate_aliased(changeset) do
    if get_field(changeset, :aliased_tag_id) do
      changeset
    else
      add_error(changeset, :aliased_tag, "is not aliased")
    end
  end

  def creation_changeset(tag, attrs) do
    tag
    |> cast(attrs, [:name])
    |> validate_required([:name])
    |> validate_length(:name, max: @name_length_limit, count: :bytes)
    |> check_constraint(:name,
      name: :tags_name_length_check,
      message: "should be at most #{@name_length_limit} byte(s)"
    )
    |> put_slug()
    |> put_name_and_namespace()
    |> put_namespace_category()
  end

  def deletion_changeset(tag) do
    changeset = change(tag)

    if get_field(changeset, :category) == "rating" do
      add_error(changeset, :category, "cannot delete a rating tag")
    else
      changeset
    end
  end

  defp maybe_put_implied_tag_list(changeset, tag) do
    if get_field(changeset, :implied_tag_list) do
      changeset
    else
      put_change(changeset, :implied_tag_list, Enum.map_join(tag.implied_tags, ",", & &1.name))
    end
  end

  def parse_tag_list(list) do
    list
    |> to_string()
    |> String.split(",")
    |> Enum.map(&clean_tag_name/1)
    |> Enum.reject(&(&1 == "" or oversized_name?(&1)))
    |> Enum.uniq()
  end

  def original_character_tag?(%__MODULE__{} = tag) do
    tag.namespace == "oc"
  end

  def original_character_tag_name do
    "oc"
  end

  # Oversized names are filtered before bulk tag insertion so they cannot
  # bypass changeset validation and trip tags_name_length_check.
  defp oversized_name?(name), do: byte_size(name) > @name_length_limit

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

  defp validate_incoming_aliases(changeset, incoming_aliases?) do
    if incoming_aliases? do
      add_error(changeset, :tag, "has incoming aliases and cannot be aliased")
    else
      changeset
    end
  end

  defp validate_no_aliased_implied_tags(changeset, implied_tags) do
    if Enum.any?(implied_tags, &(not is_nil(&1.aliased_tag_id))) do
      add_error(changeset, :implied_tag_list, "contains aliased tags")
    else
      changeset
    end
  end

  defp validate_implied_by_tags(changeset, implied_by_tags?) do
    if implied_by_tags? do
      add_error(changeset, :tag, "is implied by other tags and cannot be aliased")
    else
      changeset
    end
  end
end
