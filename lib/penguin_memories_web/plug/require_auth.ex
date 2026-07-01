defmodule PenguinMemoriesWeb.Plug.RequireAuth do
  @moduledoc """
  Redirect to the OIDC authorize endpoint when no user is logged in
  """
  @behaviour Plug

  alias PenguinMemoriesWeb.Router.Helpers, as: Routes

  import Phoenix.Controller, only: [redirect: 2]
  import Plug.Conn

  @impl Plug
  def init(opts), do: opts

  @impl Plug
  def call(conn, _opts) do
    case get_session(conn, :claims) do
      nil ->
        return_to =
          case conn.query_string do
            "" -> conn.request_path
            qs -> conn.request_path <> "?" <> qs
          end

        conn
        |> redirect(to: Routes.auth_path(conn, :authorize, state: return_to))
        |> halt()

      _claims ->
        conn
    end
  end
end
