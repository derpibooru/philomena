defmodule Philomena.Schema.ApprovalTest do
  use ExUnit.Case, async: true

  alias Philomena.Comments.Comment
  alias Philomena.Schema.Approval
  alias Philomena.Users.User

  defp new_user(attrs \\ []) do
    struct!(%User{role: "user", verified: false, created_at: DateTime.utc_now()}, attrs)
  end

  defp site_domain do
    :philomena
    |> Application.get_env(:site_domains)
    |> String.split(",")
    |> hd()
  end

  describe "trusted?/1" do
    test "trusts staff, verified users, and accounts older than 14 days" do
      refute Approval.trusted?(nil)
      refute Approval.trusted?(new_user())

      assert Approval.trusted?(new_user(role: "assistant"))
      assert Approval.trusted?(new_user(verified: true))
      assert Approval.trusted?(new_user(created_at: DateTime.add(DateTime.utc_now(), -15, :day)))
    end
  end

  describe "approved?/3" do
    test "approves empty bodies and any body from a trusted user" do
      assert Approval.approved?(new_user(), nil, :external_links)
      assert Approval.approved?(new_user(), "", :external_links)

      assert Approval.approved?(
               new_user(verified: true),
               "https://spam.example/",
               :external_links
             )
    end

    test "holds external links but not links to this site or its CDN" do
      cdn = Application.get_env(:philomena, :cdn_host)

      for body <- [
            "https://#{site_domain()}",
            "https://#{site_domain()}/images/1",
            "http://#{site_domain()}:8080/",
            "https://#{site_domain()}?q=1",
            "[link](HTTPS://#{String.upcase(site_domain())})",
            "https://#{cdn}/img/1.png"
          ] do
        assert Approval.approved?(new_user(), body, :external_links), body
      end

      for body <- [
            "https://spam.example/",
            "https\\://spam.example/",
            "HTTPS://spam.example/",
            "https://#{site_domain()}.spam.example/",
            "https://#{site_domain()}@spam.example/",
            "https://#{site_domain()}:x@spam.example/",
            "https://#{site_domain()}:8080@spam.example/"
          ] do
        refute Approval.approved?(new_user(), body, :external_links), body
      end
    end

    test "holds image embeds" do
      assert Approval.approved?(new_user(), "[link](/images/1)", :image_embeds)
      refute Approval.approved?(new_user(), "![embed](/images/1)", :image_embeds)
    end
  end

  describe "maybe_put_approval/3" do
    test "unapproves a valid body change that needs review" do
      changeset =
        %Comment{approved: true}
        |> Ecto.Changeset.change(body: "https://spam.example/")
        |> Approval.maybe_put_approval(new_user(), :external_links)

      assert Ecto.Changeset.get_change(changeset, :approved) == false
      assert Ecto.Changeset.get_change(changeset, :became_unapproved?)
    end

    test "leaves a changeset without a body change untouched" do
      changeset = Ecto.Changeset.change(%Comment{approved: true}, anonymous: true)

      assert Approval.maybe_put_approval(changeset, new_user(), :external_links) == changeset
    end
  end

  describe "approve_changeset/1" do
    test "approves an unapproved record and rejects an approved one" do
      assert %Comment{approved: false}
             |> Ecto.Changeset.change()
             |> Approval.approve_changeset()
             |> Ecto.Changeset.get_change(:approved)

      refute %Comment{approved: true}
             |> Ecto.Changeset.change()
             |> Approval.approve_changeset()
             |> Map.fetch!(:valid?)
    end
  end
end
