defmodule PenguinMemoriesWeb.Auth do
  @moduledoc """
  Helper functions for authorization
  """

  @spec current_user(Plug.Conn.t()) :: map()
  def current_user(conn) do
    Plug.Conn.get_session(conn, :claims)
  end
end
