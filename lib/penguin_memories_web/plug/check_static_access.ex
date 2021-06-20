defmodule PenguinMemoriesWeb.Plug.CheckStaticAccess do
  @moduledoc """
  Check user is authorized to see image file
  """
  import Plug.Conn
  import Phoenix.Controller

  alias PenguinMemoriesWeb.Router.Helpers, as: Routes

  def init(_default) do
  end

  def call(%Plug.Conn{} = conn, _default) do
    user = Guardian.Plug.current_resource(conn)

    orig_dir = "/images/orig"
    relative_dir = Path.relative_to(conn.request_path, orig_dir)
    is_orig_dir = not String.starts_with?(relative_dir, "/")

    can_see =
      case is_orig_dir do
        true -> PenguinMemories.Auth.can_see_orig(user)
        false -> true
      end

    case can_see do
      true ->
        conn

      false ->
        conn
        |> put_flash(:danger, "You are not allowed to see this file.")
        |> redirect(to: Routes.session_path(conn, :login, next: conn.request_path))
        |> halt()
    end
  end
end
