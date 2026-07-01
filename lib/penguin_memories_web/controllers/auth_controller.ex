defmodule PenguinMemoriesWeb.AuthController do
  @moduledoc """
  OpenID Connect login flow using oidcc
  """
  use PenguinMemoriesWeb, :controller

  alias Oidcc.Plug.AuthorizationCallback
  alias Oidcc.Plug.Authorize
  alias Oidcc.Token

  require Logger

  @spec authorize(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def authorize(conn, _params) do
    opts =
      common_opts(conn)
      |> Keyword.put(:scopes, scopes())
      |> Authorize.init()

    Authorize.call(conn, opts)
  end

  @spec callback(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def callback(conn, _params) do
    opts =
      common_opts(conn)
      |> Keyword.put(:retrieve_userinfo, false)
      |> AuthorizationCallback.init()

    conn = AuthorizationCallback.call(conn, opts)
    handle_result(conn, conn.private[AuthorizationCallback], conn.private[Authorize.State])
  end

  @spec handle_result(
          Plug.Conn.t(),
          {:ok, {Token.t(), map() | nil}} | {:error, any()},
          String.t() | nil
        ) :: Plug.Conn.t()
  defp handle_result(conn, {:ok, {%{id: %{claims: id_claims}}, _userinfo}}, state) do
    claims = Map.take(id_claims, ["groups", "name", "sub"])
    sub = claims["sub"]

    conn
    |> configure_session(renew: true)
    |> put_session(:claims, claims)
    |> put_session(:live_socket_id, "users_socket:#{sub}")
    |> redirect(to: return_to(state))
  end

  defp handle_result(conn, result, _state) do
    Logger.error("OIDC callback failed: #{inspect(result)}")

    conn
    |> put_flash(:danger, "Login failed.")
    |> redirect(to: Routes.page_path(conn, :index))
  end

  @spec common_opts(Plug.Conn.t()) :: keyword()
  defp common_opts(conn) do
    config = Application.get_env(:penguin_memories, :oidc)

    [
      provider: PenguinMemories.OidcProviderConfig,
      client_id: config.client_id,
      client_secret: config.client_secret,
      redirect_uri: Routes.auth_url(conn, :callback)
    ]
  end

  @spec scopes() :: [String.t()]
  defp scopes do
    Application.get_env(:penguin_memories, :oidc).scope
    |> String.split(" ", trim: true)
  end

  @spec return_to(String.t() | nil) :: String.t()
  defp return_to("/" <> _rest = path) do
    if String.starts_with?(path, "//"), do: "/", else: path
  end

  defp return_to(_state), do: "/"
end
