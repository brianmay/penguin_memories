defmodule PenguinMemories.Accounts.ErrorHandler do
  @moduledoc "Error handler"
  import Plug.Conn
  use PenguinMemoriesWeb, :controller

  @behaviour Guardian.Plug.ErrorHandler

  @impl Guardian.Plug.ErrorHandler
  def auth_error(conn, {type, _reason}, _opts) do
    body = to_string(type)

    conn
    |> put_flash(:danger, "Permission denied: #{body}")
  end
end
