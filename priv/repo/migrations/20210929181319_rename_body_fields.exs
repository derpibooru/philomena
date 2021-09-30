defmodule Philomena.Repo.Migrations.RenameBodyFields do
  use Ecto.Migration

  def change do
    # Rename textile fields to *_textile,
    # while putting Markdown fields in their place.
    rename table("comments"), :body, to: :body_textile
    rename table("comments"), :body_md, to: :body

    rename table("messages"), :body, to: :body_textile
    rename table("messages"), :body_md, to: :body

    rename table("mod_notes"), :body, to: :body_textile
    rename table("mod_notes"), :body_md, to: :body

    rename table("posts"), :body, to: :body_textile
    rename table("posts"), :body_md, to: :body

    rename table("commission_items"), :description, to: :description_textile
    rename table("commission_items"), :add_ons, to: :add_ons_textile
    rename table("commission_items"), :description_md, to: :description
    rename table("commission_items"), :add_ons_md, to: :add_ons

    rename table("images"), :description, to: :description_textile
    rename table("images"), :scratchpad, to: :scratchpad_textile
    rename table("images"), :description_md, to: :description
    rename table("images"), :scratchpad_md, to: :scratchpad

    rename table("tags"), :description, to: :description_textile
    rename table("tags"), :description_md, to: :description

    rename table("users"), :description, to: :description_textile
    rename table("users"), :scratchpad, to: :scratchpad_textile
    rename table("users"), :description_md, to: :description
    rename table("users"), :scratchpad_md, to: :scratchpad

    rename table("dnp_entries"), :conditions, to: :conditions_textile
    rename table("dnp_entries"), :reason, to: :reason_textile
    rename table("dnp_entries"), :instructions, to: :instructions_textile
    rename table("dnp_entries"), :conditions_md, to: :conditions
    rename table("dnp_entries"), :reason_md, to: :reason
    rename table("dnp_entries"), :instructions_md, to: :instructions

    rename table("commissions"), :information, to: :information_textile
    rename table("commissions"), :contact, to: :contact_textile
    rename table("commissions"), :will_create, to: :will_create_textile
    rename table("commissions"), :will_not_create, to: :will_not_create_textile
    rename table("commissions"), :information_md, to: :information
    rename table("commissions"), :contact_md, to: :contact
    rename table("commissions"), :will_create_md, to: :will_create
    rename table("commissions"), :will_not_create_md, to: :will_not_create

    rename table("reports"), :reason, to: :reason_textile
    rename table("reports"), :reason_md, to: :reason

    # Change constraints
    alter table("comments") do
      modify :body_textile, :varchar, default: ""
      modify :body, :varchar, null: false
    end

    alter table("posts") do
      modify :body_textile, :varchar, default: ""
      modify :body, :varchar, null: false
    end

    alter table("messages") do
      modify :body_textile, :varchar, default: ""
      modify :body, :varchar, null: false
    end

    alter table("mod_notes") do
      modify :body_textile, :text, default: ""
      modify :body, :varchar, null: false
    end

    alter table("dnp_entries") do
      modify :reason_textile, :varchar, default: ""
      modify :reason, :varchar, null: false

      modify :conditions_textile, :varchar, default: ""
      modify :conditions, :varchar, null: false

      modify :instructions_textile, :varchar, default: ""
      modify :instructions, :varchar, null: false
    end

    alter table("reports") do
      modify :reason_textile, :varchar, default: ""
      modify :reason, :varchar, null: false
    end

    execute("update images set description='' where description is null;")
    execute("update tags set description='' where description is null;")

    execute(
      "alter table images alter column description set default ''::character varying, alter column description set not null;"
    )

    execute(
      "alter table tags alter column description set default ''::character varying, alter column description set not null;"
    )

    # Unneeded columns
    alter table("badges") do
      remove :description_md, :varchar, default: nil
    end

    alter table("channels") do
      remove :description, :varchar, default: ""
      remove :description_md, :varchar, default: ""
    end

    alter table("filters") do
      remove :description_md, :varchar, default: nil
    end

    alter table("galleries") do
      remove :description_md, :varchar, default: nil
    end
  end
end
