defmodule PhilomenaWeb.Registration.NewController do
  use PhilomenaWeb, :controller

  alias Plug.Conn

  plug :verify_captcha
  plug PhilomenaWeb.NameLengthLimiterPlug
  plug PhilomenaWeb.NotableNamePlug

  @doc """
  Create new user, if everything seems to be in order.
  """
  @spec create(Conn.t(), map()) :: Conn.t()
  def create(conn, %{"user" => user_params}) do
    alias Pow.Plug

    conn
      |> Plug.create_user(user_params)
      |> yea_neigh()
  end

  @doc """
  Greet new user, or return to registration page on fail.
  """
  @spec yea_neigh({:ok | :error, map(), Conn.t()}) :: Conn.t()
  defp yea_neigh({:ok, _user, conn}) do
    conn
    |> put_flash(:info, "Mellow greetings, citizen!")
    |> redirect(to: "/")
  end
  defp yea_neigh({:error, changeset, conn}) do
    conn
    |> assign(:changeset, changeset)
    |> render("new.html")
  end

  @doc """
  Verify captcha.
  """
  defp verify_captcha(conn, _opts) do
    alias Pow.Plug
    alias Pow.Config
    alias Phoenix.Controller

    config   = Plug.fetch_config(conn)
    verifier = Config.get(config, :captcha_verifier)

    case verifier.valid_solution?(conn.params) do
      false ->
        conn
          |> Controller.put_flash(:error,
            "There was an error verifying you're not a robot. Please try again.")
          |> Controller.redirect(external: conn.assigns.referrer)
          |> Conn.halt()
      true ->
        conn
    end
  end
end
