defmodule Philomena.PollOptionsTest do
  use Philomena.DataCase

  alias Philomena.PollOptions

  describe "poll_options" do
    alias Philomena.PollOptions.PollOption

    @valid_attrs %{}
    @update_attrs %{}
    @invalid_attrs %{}

    def poll_option_fixture(attrs \\ %{}) do
      {:ok, poll_option} =
        attrs
        |> Enum.into(@valid_attrs)
        |> PollOptions.create_poll_option()

      poll_option
    end

    test "list_poll_options/0 returns all poll_options" do
      poll_option = poll_option_fixture()
      assert PollOptions.list_poll_options() == [poll_option]
    end

    test "get_poll_option!/1 returns the poll_option with given id" do
      poll_option = poll_option_fixture()
      assert PollOptions.get_poll_option!(poll_option.id) == poll_option
    end

    test "create_poll_option/1 with valid data creates a poll_option" do
      assert {:ok, %PollOption{} = poll_option} = PollOptions.create_poll_option(@valid_attrs)
    end

    test "create_poll_option/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = PollOptions.create_poll_option(@invalid_attrs)
    end

    test "update_poll_option/2 with valid data updates the poll_option" do
      poll_option = poll_option_fixture()
      assert {:ok, %PollOption{} = poll_option} = PollOptions.update_poll_option(poll_option, @update_attrs)
    end

    test "update_poll_option/2 with invalid data returns error changeset" do
      poll_option = poll_option_fixture()
      assert {:error, %Ecto.Changeset{}} = PollOptions.update_poll_option(poll_option, @invalid_attrs)
      assert poll_option == PollOptions.get_poll_option!(poll_option.id)
    end

    test "delete_poll_option/1 deletes the poll_option" do
      poll_option = poll_option_fixture()
      assert {:ok, %PollOption{}} = PollOptions.delete_poll_option(poll_option)
      assert_raise Ecto.NoResultsError, fn -> PollOptions.get_poll_option!(poll_option.id) end
    end

    test "change_poll_option/1 returns a poll_option changeset" do
      poll_option = poll_option_fixture()
      assert %Ecto.Changeset{} = PollOptions.change_poll_option(poll_option)
    end
  end
end
