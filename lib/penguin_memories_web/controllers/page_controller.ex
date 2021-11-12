defmodule PenguinMemoriesWeb.PageController do
  use PenguinMemoriesWeb, :controller

  @spec logout(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def logout(conn, _params) do
    user = PenguinMemoriesWeb.Auth.current_user(conn)

    if user != nil do
      sub = user["sub"]
      PenguinMemoriesWeb.Endpoint.broadcast("users_socket:#{sub}", "disconnect", %{})
    end

    next =
      case conn.query_params["next"] do
        "" -> Routes.page_path(conn, :index)
        nil -> Routes.page_path(conn, :index)
        next -> next
      end

    conn
    |> Plugoid.logout()
    |> put_session(:claims, nil)
    |> put_flash(:danger, "You are now logged out.")
    |> redirect(to: next)
  end

  @spec login(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def login(conn, _params) do
    next =
      case conn.query_params["next"] do
        "" -> Routes.page_path(conn, :index)
        nil -> Routes.page_path(conn, :index)
        next -> next
      end

    redirect(conn, to: next)
  end
end
