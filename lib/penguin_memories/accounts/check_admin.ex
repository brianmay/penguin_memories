defmodule PenguinMemories.Accounts.CheckAdmin do
  import Plug.Conn
  use PenguinMemoriesWeb, :controller

  def init(_params) do
  end

  def call(conn, _params) do
    user = Guardian.Plug.current_resource(conn)

    if not user.is_admin do
      conn
      |> put_flash(:error, "Permission denied: Not authorized")
      |> redirect(to: Routes.session_path(conn, :login))
      |> halt()
    else
      conn
    end
  end
end
