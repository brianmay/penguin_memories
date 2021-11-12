defmodule PenguinMemoriesWeb.Plug.CheckAdmin do
  @moduledoc "Check if user is administrator"
  import Plug.Conn
  use PenguinMemoriesWeb, :controller

  def init(_params) do
  end

  def call(conn, _params) do
    user = PenguinMemoriesWeb.Auth.current_user(conn)

    if PenguinMemories.Auth.user_is_admin?(user) do
      conn
    else
      conn
      |> put_flash(:danger, "You must be admin to access this.")
      |> redirect(to: Routes.page_path(conn, :index))
      |> halt()
    end
  end
end
