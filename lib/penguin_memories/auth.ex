defmodule PenguinMemories.Auth do
  @moduledoc """
  Functions that assist with authentication.
  """
  alias PenguinMemories.Accounts.Guardian
  alias PenguinMemories.Accounts.User

  def current_user(conn) do
    Guardian.Plug.current_resource(conn)
  end

  def user_signed_in?(conn) do
    !!current_user(conn)
  end

  def user_is_admin?(conn) do
    current_user(conn).is_admin
  end

  @spec can_edit(User.t() | nil) :: boolean
  def can_edit(nil), do: false
  def can_edit(_), do: true

  @token_key "guardian_default_token"
  @spec load_user(map()) :: {:ok, User.t()} | {:error, atom()} | :not_logged_in
  def load_user(%{@token_key => token}) do
    case Guardian.decode_and_verify(token) do
      {:ok, claims} ->
         Guardian.resource_from_claims(claims)
      _ ->
        nil
    end
  end
  def load_user(_), do: :not_logged_in

end
