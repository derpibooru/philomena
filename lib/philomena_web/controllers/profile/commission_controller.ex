defmodule PhilomenaWeb.Profile.CommissionController do
  use PhilomenaWeb, :controller

  alias Philomena.Commissions
  alias PhilomenaWeb.MarkdownRenderer

  action_fallback PhilomenaWeb.FallbackController

  def show(conn, %{"profile_id" => slug}) do
    with {:ok, commission} <-
           Commissions.show_commission(conn.assigns.actor, slug) do
      item_descriptions =
        commission.items
        |> Enum.map(&%{body: &1.description})
        |> MarkdownRenderer.render_collection(conn)

      item_add_ons =
        commission.items
        |> Enum.map(&%{body: &1.add_ons})
        |> MarkdownRenderer.render_collection(conn)

      [information, contact, will_create, will_not_create] =
        MarkdownRenderer.render_collection(
          [
            %{body: commission.information || ""},
            %{body: commission.contact || ""},
            %{body: commission.will_create || ""},
            %{body: commission.will_not_create || ""}
          ],
          conn
        )

      rendered = %{
        information: information,
        contact: contact,
        will_create: will_create,
        will_not_create: will_not_create
      }

      items = Enum.zip([item_descriptions, item_add_ons, commission.items])

      render(conn, "show.html",
        title: "Showing Commission",
        user: commission.user,
        rendered: rendered,
        commission: commission,
        items: items,
        layout_class: "layout--wide"
      )
    end
  end

  def new(conn, %{"profile_id" => slug}) do
    case Commissions.new_commission(conn.assigns.actor, slug) do
      {:ok, %Ecto.Changeset{data: commission} = changeset} ->
        render(conn, "new.html",
          title: "New Commission",
          user: commission.user,
          changeset: changeset
        )

      {:error, :no_verified_links} ->
        require_verified_link(conn)

      error ->
        error
    end
  end

  def create(conn, %{"profile_id" => slug, "commission" => commission_params}) do
    case Commissions.create_commission(conn.assigns.actor, slug, commission_params) do
      {:ok, %{user: user} = _commission} ->
        conn
        |> put_flash(:info, "Commission successfully created.")
        |> redirect(to: ~p"/profiles/#{user}/commission")

      {:error, %Ecto.Changeset{data: commission} = changeset} ->
        render(conn, "new.html", user: commission.user, changeset: changeset)

      {:error, :no_verified_links} ->
        require_verified_link(conn)

      error ->
        error
    end
  end

  def edit(conn, %{"profile_id" => slug}) do
    case Commissions.edit_commission(conn.assigns.actor, slug) do
      {:ok, %Ecto.Changeset{data: commission} = changeset} ->
        render(conn, "edit.html",
          title: "Editing Commission",
          user: commission.user,
          changeset: changeset
        )

      error ->
        error
    end
  end

  def update(conn, %{"profile_id" => slug, "commission" => commission_params}) do
    case Commissions.update_commission(conn.assigns.actor, slug, commission_params) do
      {:ok, %{user: user} = _commission} ->
        conn
        |> put_flash(:info, "Commission successfully updated.")
        |> redirect(to: ~p"/profiles/#{user}/commission")

      {:error, %Ecto.Changeset{data: commission} = changeset} ->
        render(conn, "edit.html", user: commission.user, changeset: changeset)

      error ->
        error
    end
  end

  def delete(conn, %{"profile_id" => slug}) do
    case Commissions.delete_commission(conn.assigns.actor, slug) do
      {:ok, _commission} ->
        conn
        |> put_flash(:info, "Commission deleted successfully.")
        |> redirect(to: ~p"/commissions")

      error ->
        error
    end
  end

  defp require_verified_link(conn) do
    conn
    |> put_flash(
      :error,
      "You must have a verified artist link to create a commission listing."
    )
    |> redirect(to: ~p"/commissions")
  end
end
