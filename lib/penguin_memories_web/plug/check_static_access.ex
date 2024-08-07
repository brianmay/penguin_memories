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
    user = PenguinMemoriesWeb.Auth.current_user(conn)

    is_protected_dir =
      ["/images/orig"]
      |> Enum.any?(fn orig_dir ->
        relative_dir = Path.relative_to(conn.request_path, orig_dir)
        not String.starts_with?(relative_dir, "/")
      end)

    can_see =
      case is_protected_dir do
        true -> PenguinMemories.Auth.can_see_orig(user)
        false -> true
      end

    case can_see do
      true ->
        conn

      false ->
        conn
        |> put_flash(:danger, "You are not allowed to see this file.")
        |> redirect(to: Routes.page_path(conn, :index, next: conn.request_path))
        |> halt()
    end
  end
end
