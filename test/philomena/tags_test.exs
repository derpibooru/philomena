defmodule Philomena.TagsTest do
  use Philomena.DataCase

  alias Philomena.Tags

  describe "tags" do
    alias Philomena.Tags.Tag

    @valid_attrs %{}
    @update_attrs %{}
    @invalid_attrs %{}

    def tag_fixture(attrs \\ %{}) do
      {:ok, tag} =
        attrs
        |> Enum.into(@valid_attrs)
        |> Tags.create_tag()

      tag
    end

    test "list_tags/0 returns all tags" do
      tag = tag_fixture()
      assert Tags.list_tags() == [tag]
    end

    test "get_tag!/1 returns the tag with given id" do
      tag = tag_fixture()
      assert Tags.get_tag!(tag.id) == tag
    end

    test "create_tag/1 with valid data creates a tag" do
      assert {:ok, %Tag{} = tag} = Tags.create_tag(@valid_attrs)
    end

    test "create_tag/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Tags.create_tag(@invalid_attrs)
    end

    test "update_tag/2 with valid data updates the tag" do
      tag = tag_fixture()
      assert {:ok, %Tag{} = tag} = Tags.update_tag(tag, @update_attrs)
    end

    test "update_tag/2 with invalid data returns error changeset" do
      tag = tag_fixture()
      assert {:error, %Ecto.Changeset{}} = Tags.update_tag(tag, @invalid_attrs)
      assert tag == Tags.get_tag!(tag.id)
    end

    test "delete_tag/1 deletes the tag" do
      tag = tag_fixture()
      assert {:ok, %Tag{}} = Tags.delete_tag(tag)
      assert_raise Ecto.NoResultsError, fn -> Tags.get_tag!(tag.id) end
    end

    test "change_tag/1 returns a tag changeset" do
      tag = tag_fixture()
      assert %Ecto.Changeset{} = Tags.change_tag(tag)
    end
  end

  describe "tags_implied_tags" do
    alias Philomena.Tags.Implication

    @valid_attrs %{}
    @update_attrs %{}
    @invalid_attrs %{}

    def implication_fixture(attrs \\ %{}) do
      {:ok, implication} =
        attrs
        |> Enum.into(@valid_attrs)
        |> Tags.create_implication()

      implication
    end

    test "list_tags_implied_tags/0 returns all tags_implied_tags" do
      implication = implication_fixture()
      assert Tags.list_tags_implied_tags() == [implication]
    end

    test "get_implication!/1 returns the implication with given id" do
      implication = implication_fixture()
      assert Tags.get_implication!(implication.id) == implication
    end

    test "create_implication/1 with valid data creates a implication" do
      assert {:ok, %Implication{} = implication} = Tags.create_implication(@valid_attrs)
    end

    test "create_implication/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Tags.create_implication(@invalid_attrs)
    end

    test "update_implication/2 with valid data updates the implication" do
      implication = implication_fixture()

      assert {:ok, %Implication{} = implication} =
               Tags.update_implication(implication, @update_attrs)
    end

    test "update_implication/2 with invalid data returns error changeset" do
      implication = implication_fixture()
      assert {:error, %Ecto.Changeset{}} = Tags.update_implication(implication, @invalid_attrs)
      assert implication == Tags.get_implication!(implication.id)
    end

    test "delete_implication/1 deletes the implication" do
      implication = implication_fixture()
      assert {:ok, %Implication{}} = Tags.delete_implication(implication)
      assert_raise Ecto.NoResultsError, fn -> Tags.get_implication!(implication.id) end
    end

    test "change_implication/1 returns a implication changeset" do
      implication = implication_fixture()
      assert %Ecto.Changeset{} = Tags.change_implication(implication)
    end
  end
end
