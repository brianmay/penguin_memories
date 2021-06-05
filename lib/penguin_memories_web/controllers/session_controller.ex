defmodule PenguinMemoriesWeb.SessionController do
  use PenguinMemoriesWeb, :controller

  alias PenguinMemories.{Accounts, Accounts.Guardian}
  alias PenguinMemoriesWeb.Router.Helpers, as: Routes

  def login(conn, %{"user" => %{"username" => username, "password" => password}}) do
    Accounts.authenticate_user(username, password)
    |> login_reply(conn)
  end

  def logout(conn, _) do
    user = PenguinMemories.Auth.current_user(conn)

    next =
      case conn.query_params["next"] do
        "" -> Routes.page_path(conn, :index)
        nil -> Routes.page_path(conn, :index)
        next -> next
      end

    conn =
      conn
      |> Guardian.Plug.sign_out()
      |> redirect(to: next)

    PenguinMemoriesWeb.Endpoint.broadcast("users_socket:#{user.id}", "disconnect", %{})
    conn
  end

  defp login_reply({:ok, user}, conn) do
    next =
      case conn.query_params["next"] do
        "" -> Routes.page_path(conn, :index)
        nil -> Routes.page_path(conn, :index)
        next -> next
      end

    conn
    |> put_flash(:info, "Welcome back!")
    |> put_session(:live_socket_id, "users_socket:#{user.id}")
    |> Accounts.Guardian.Plug.sign_in(user)
    |> redirect(to: next)
  end

  defp login_reply({:error, reason}, conn) do
    conn
    |> put_flash(:danger, to_string(reason))
    |> redirect(to: Routes.session_path(conn, :login))
  end
end
