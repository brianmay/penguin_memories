defmodule PenguinMemoriesWeb.Router do
  use PenguinMemoriesWeb, :router
  import Phoenix.LiveDashboard.Router

  use Plugoid.RedirectURI,
    token_callback: &PenguinMemoriesWeb.TokenCallback.callback/5

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, {PenguinMemoriesWeb.LayoutView, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :static do
    plug PenguinMemoriesWeb.Plug.CheckStaticAccess

    plug PenguinMemoriesWeb.Plug.Static,
      at: "/images",
      gzip: false
  end

  defmodule PlugoidConfig do
    def common do
      config = Application.get_env(:penguin_memories, :oidc)

      [
        issuer: config.discovery_document_uri,
        client_id: config.client_id,
        scope: String.split(config.scope, " "),
        client_config: PenguinMemoriesWeb.ClientCallback
      ]
    end
  end

  # We use ensure_auth to fail if there is no one logged in
  pipeline :auth do
    plug Replug,
      plug: {Plugoid, on_unauthenticated: :pass},
      opts: {PlugoidConfig, :common}
  end

  pipeline :ensure_auth do
    plug Replug,
      plug: {Plugoid, on_unauthenticated: :auth},
      opts: {PlugoidConfig, :common}
  end

  pipeline :ensure_admin do
    plug PenguinMemoriesWeb.Plug.CheckAdmin
  end

  scope "/", PenguinMemoriesWeb do
    get "/_health", HealthCheckController, :index
  end

  scope "/", PenguinMemoriesWeb do
    pipe_through [:browser, :auth, :ensure_admin]

    live_dashboard "/dashboard",
      metrics: PenguinMemoriesWeb.Telemetry,
      ecto_repos: [PenguinMemories.Repo]
  end

  live_session :default, on_mount: PenguinMemoriesWeb.InitAssigns do
    scope "/images", PenguinMemoriesWeb do
      pipe_through [:browser, :auth, :static]
      get "/*path", FileNotFoundController, :index
    end

    scope "/", PenguinMemoriesWeb do
      pipe_through [:browser, :ensure_auth]

      get "/login", PageController, :login
    end

    scope "/", PenguinMemoriesWeb do
      pipe_through [:browser, :auth]
      PenguinMemoriesWeb
      live "/", PageLive, :index
      post "/logout", PageController, :logout
      get "/file/:id/size/:size/", RedirectController, :photo
      live "/:type/", MainLive, :index
      live "/:type/:id/", MainLive, :index
    end
  end
end
