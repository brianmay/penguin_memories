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

  @spec user_is_admin?(User.t() | nil) :: boolean()
  def user_is_admin?(nil), do: false
  def user_is_admin?(%User{} = user), do: user.is_admin

  @spec can_edit(User.t() | nil) :: boolean
  def can_edit(nil), do: false
  def can_edit(%User{}), do: true

  @spec can_see_private(User.t() | nil) :: boolean
  def can_see_private(nil), do: false
  def can_see_private(_), do: true

  @token_key "guardian_default_token"
  @spec load_user(map()) :: {:ok, User.t()} | {:error, atom()} | :not_logged_in
  def load_user(%{@token_key => token}) do
    case Guardian.decode_and_verify(token) do
      {:ok, claims} ->
        Guardian.resource_from_claims(claims)

      _ ->
        {:error, :invalid_token}
    end
  end

  def load_user(_), do: :not_logged_in
end
