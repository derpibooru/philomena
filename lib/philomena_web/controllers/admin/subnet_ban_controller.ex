defmodule PhilomenaWeb.Admin.SubnetBanController do
  use PhilomenaWeb, :controller

  alias Philomena.Bans.Subnet, as: SubnetBan
  alias Philomena.Bans
  alias Philomena.Repo
  import Ecto.Query

  plug :verify_authorized
  plug :load_resource, model: SubnetBan, only: [:edit, :update, :delete]
  plug :check_can_delete when action in [:delete]

  def index(conn, %{"q" => q}) when is_binary(q) do
    SubnetBan
    |> where(
      [sb],
      sb.generated_ban_id == ^q or
        fragment("to_tsvector(?) @@ plainto_tsquery(?)", sb.reason, ^q) or
        fragment("to_tsvector(?) @@ plainto_tsquery(?)", sb.note, ^q)
    )
    |> load_bans(conn)
  end

  def index(conn, %{"ip" => ip}) when is_binary(ip) do
    {:ok, ip} = EctoNetwork.INET.cast(ip)

    SubnetBan
    |> where([sb], fragment("? >>= ?", sb.specification, ^ip))
    |> load_bans(conn)
  end

  def index(conn, _params) do
    load_bans(SubnetBan, conn)
  end

  def new(conn, %{"specification" => ip}) do
    {:ok, ip} = EctoNetwork.INET.cast(ip)
    changeset = Bans.change_subnet(%SubnetBan{specification: ip})
    render(conn, "new.html", title: "New Subnet Ban", changeset: changeset)
  end

  def new(conn, _params) do
    changeset = Bans.change_subnet(%SubnetBan{})
    render(conn, "new.html", title: "New Subnet Ban", changeset: changeset)
  end

  def create(conn, %{"subnet" => subnet_ban_params}) do
    case Bans.create_subnet(conn.assigns.current_user, subnet_ban_params) do
      {:ok, _subnet_ban} ->
        conn
        |> put_flash(:info, "Subnet was successfully banned.")
        |> redirect(to: Routes.admin_subnet_ban_path(conn, :index))

      {:error, changeset} ->
        render(conn, "new.html", changeset: changeset)
    end
  end

  def edit(conn, _params) do
    changeset = Bans.change_subnet(conn.assigns.subnet)
    render(conn, "edit.html", title: "Editing Subnet Ban", changeset: changeset)
  end

  def update(conn, %{"subnet" => subnet_ban_params}) do
    case Bans.update_subnet(conn.assigns.subnet, subnet_ban_params) do
      {:ok, _subnet_ban} ->
        conn
        |> put_flash(:info, "Subnet ban successfully updated.")
        |> redirect(to: Routes.admin_subnet_ban_path(conn, :index))

      {:error, changeset} ->
        render(conn, "edit.html", changeset: changeset)
    end
  end

  def delete(conn, _params) do
    {:ok, _subnet_ban} = Bans.delete_subnet(conn.assigns.subnet)

    conn
    |> put_flash(:info, "Subnet ban successfully deleted.")
    |> redirect(to: Routes.admin_subnet_ban_path(conn, :index))
  end

  defp load_bans(queryable, conn) do
    subnet_bans =
      queryable
      |> order_by(desc: :created_at)
      |> preload(:banning_user)
      |> Repo.paginate(conn.assigns.scrivener)

    render(conn, "index.html",
      title: "Admin - Subnet Bans",
      layout_class: "layout--wide",
      subnet_bans: subnet_bans
    )
  end

  defp verify_authorized(conn, _opts) do
    case Canada.Can.can?(conn.assigns.current_user, :index, SubnetBan) do
      true -> conn
      false -> PhilomenaWeb.NotAuthorizedPlug.call(conn)
    end
  end

  defp check_can_delete(conn, _opts) do
    case conn.assigns.current_user.role == "admin" do
      true -> conn
      false -> PhilomenaWeb.NotAuthorizedPlug.call(conn)
    end
  end
end
