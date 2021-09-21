defmodule Philomena.Repo.Migrations.AddMarkdownColumns do
  use Ecto.Migration

  def up do
    alter table("comments") do
      add :body_md, :varchar, default: nil
    end

    alter table("messages") do
      add :body_md, :varchar, default: nil
    end

    alter table("mod_notes") do
      add :body_md, :varchar, default: nil
    end

    alter table("posts") do
      add :body_md, :varchar, default: nil
    end

    alter table("badges") do
      add :description_md, :varchar, default: nil
    end

    alter table("channels") do
      add :description_md, :varchar, default: nil
    end

    alter table("commission_items") do
      add :description_md, :varchar, default: nil
      add :add_ons_md, :varchar, default: nil
    end

    alter table("filters") do
      add :description_md, :varchar, default: nil
    end

    alter table("galleries") do
      add :description_md, :varchar, default: nil
    end

    alter table("images") do
      add :description_md, :varchar, default: nil
      add :scratchpad_md, :varchar, default: nil
    end

    alter table("tags") do
      add :description_md, :varchar, default: nil
    end

    alter table("users") do
      add :description_md, :varchar, default: nil
      add :scratchpad_md, :varchar, default: nil
    end

    alter table("dnp_entries") do
      add :conditions_md, :varchar, default: nil
      add :reason_md, :varchar, default: nil
      add :instructions_md, :varchar, default: nil
    end

    alter table("commissions") do
      add :information_md, :varchar, default: nil
      add :contact_md, :varchar, default: nil
      add :will_create_md, :varchar, default: nil
      add :will_not_create_md, :varchar, default: nil
    end

    alter table("reports") do
      add :reason_md, :varchar, default: nil
    end
  end

  def down do
    alter table("comments") do
      remove :body_md
    end

    alter table("messages") do
      remove :body_md
    end

    alter table("mod_notes") do
      remove :body_md
    end

    alter table("posts") do
      remove :body_md
    end

    alter table("badges") do
      remove :description_md
    end

    alter table("channels") do
      remove :description_md
    end

    alter table("commission_items") do
      remove :description_md
      remove :add_ons_md
    end

    alter table("filters") do
      remove :description_md
    end

    alter table("galleries") do
      remove :description_md
    end

    alter table("images") do
      remove :description_md
      remove :scratchpad_md
    end

    alter table("tags") do
      remove :description_md
      remove :short_description_md
      remove :mod_notes_md
    end

    alter table("users") do
      remove :description_md
      remove :scratchpad_md
    end

    alter table("dnp_entries") do
      remove :conditions_md
      remove :reason_md
      remove :instructions_md
    end

    alter table("commissions") do
      remove :information_md
      remove :contact_md
      remove :will_create_md
      remove :will_not_create_md
    end

    alter table("reports") do
      remove :reason_md
    end
  end
end
