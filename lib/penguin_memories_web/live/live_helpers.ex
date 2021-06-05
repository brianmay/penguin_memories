defmodule MyAppWeb.LiveHelpers do
  @moduledoc """
  Helpers for all live modules.
  """
  import Phoenix.LiveView
  alias Phoenix.LiveView.Socket

  alias PenguinMemories.Accounts.User
  alias PenguinMemories.Auth

  @spec assign_defaults(socket :: Socket.t(), session :: map()) :: Socket.t()
  def assign_defaults(%Socket{} = socket, session) do
    assigns =
      case Auth.load_user(session) do
        {:ok, %User{} = user} ->
          [user: user]

        {:error, _} ->
          [user: nil]

        :not_logged_in ->
          [user: nil]
      end

    assign(socket, assigns)
  end
end
