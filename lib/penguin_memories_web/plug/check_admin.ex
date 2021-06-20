defmodule PenguinMemoriesWeb.Plug.CheckAdmin do
  @moduledoc "Check if user is administrator"
  import Plug.Conn
  use PenguinMemoriesWeb, :controller

  def init(_params) do
  end

  def call(conn, _params) do
    user = Guardian.Plug.current_resource(conn)

    if user != nil and user.is_admin do
      conn
    else
      conn
      |> put_flash(:error, "Permission denied: Not authorized")
      |> redirect(to: Routes.session_path(conn, :login, next: conn.request_path))
      |> halt()
    end
  end
end
