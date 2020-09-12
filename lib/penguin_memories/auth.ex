defmodule PenguinMemories.Auth do
  def current_user(conn) do
    Guardian.Plug.current_resource(conn)
  end

  def user_signed_in?(conn) do
    !!current_user(conn)
  end

  def user_is_admin?(conn) do
    current_user(conn).is_admin
  end
end
