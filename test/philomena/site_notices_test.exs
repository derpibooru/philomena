defmodule Philomena.SiteNoticesTest do
  use Philomena.DataCase

  alias Philomena.SiteNotices

  describe "site_notices" do
    alias Philomena.SiteNotices.SiteNotice

    @valid_attrs %{}
    @update_attrs %{}
    @invalid_attrs %{}

    def site_notice_fixture(attrs \\ %{}) do
      {:ok, site_notice} =
        attrs
        |> Enum.into(@valid_attrs)
        |> SiteNotices.create_site_notice()

      site_notice
    end

    test "list_site_notices/0 returns all site_notices" do
      site_notice = site_notice_fixture()
      assert SiteNotices.list_site_notices() == [site_notice]
    end

    test "get_site_notice!/1 returns the site_notice with given id" do
      site_notice = site_notice_fixture()
      assert SiteNotices.get_site_notice!(site_notice.id) == site_notice
    end

    test "create_site_notice/1 with valid data creates a site_notice" do
      assert {:ok, %SiteNotice{} = site_notice} = SiteNotices.create_site_notice(@valid_attrs)
    end

    test "create_site_notice/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = SiteNotices.create_site_notice(@invalid_attrs)
    end

    test "update_site_notice/2 with valid data updates the site_notice" do
      site_notice = site_notice_fixture()
      assert {:ok, %SiteNotice{} = site_notice} = SiteNotices.update_site_notice(site_notice, @update_attrs)
    end

    test "update_site_notice/2 with invalid data returns error changeset" do
      site_notice = site_notice_fixture()
      assert {:error, %Ecto.Changeset{}} = SiteNotices.update_site_notice(site_notice, @invalid_attrs)
      assert site_notice == SiteNotices.get_site_notice!(site_notice.id)
    end

    test "delete_site_notice/1 deletes the site_notice" do
      site_notice = site_notice_fixture()
      assert {:ok, %SiteNotice{}} = SiteNotices.delete_site_notice(site_notice)
      assert_raise Ecto.NoResultsError, fn -> SiteNotices.get_site_notice!(site_notice.id) end
    end

    test "change_site_notice/1 returns a site_notice changeset" do
      site_notice = site_notice_fixture()
      assert %Ecto.Changeset{} = SiteNotices.change_site_notice(site_notice)
    end
  end
end
