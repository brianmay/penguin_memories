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

    conn =
      conn
      |> Guardian.Plug.sign_out()
      |> redirect(to: Routes.page_path(conn, :index))

    PenguinMemoriesWeb.Endpoint.broadcast("users_socket:#{user.id}", "disconnect", %{})
    conn
  end

  defp login_reply({:ok, user}, conn) do
    conn
    |> put_flash(:info, "Welcome back!")
    |> put_session(:live_socket_id, "users_socket:#{user.id}")
    |> Accounts.Guardian.Plug.sign_in(user)
    |> redirect(to: Routes.page_path(conn, :index))
  end

  defp login_reply({:error, reason}, conn) do
    conn
    |> put_flash(:danger, to_string(reason))
    |> redirect(to: Routes.session_path(conn, :login))
  end
end
