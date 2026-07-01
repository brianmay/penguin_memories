defmodule PenguinMemoriesWeb.Router do
  use PenguinMemoriesWeb, :router
  import Phoenix.LiveDashboard.Router

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

  # We use ensure_auth to fail if there is no one logged in
  pipeline :ensure_auth do
    plug PenguinMemoriesWeb.Plug.RequireAuth
  end

  # Same as :browser minus protect_from_forgery: the OP redirects/posts here
  # cross-site with no CSRF token; CSRF safety comes from the session-bound
  # state verifier + PKCE + nonce inside Oidcc.Plug.AuthorizationCallback.
  pipeline :oidc_callback do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, {PenguinMemoriesWeb.LayoutView, :root}
    plug :put_secure_browser_headers
  end

  pipeline :ensure_admin do
    plug PenguinMemoriesWeb.Plug.CheckAdmin
  end

  scope "/", PenguinMemoriesWeb do
    get "/_health", HealthCheckController, :index
  end

  scope "/", PenguinMemoriesWeb do
    pipe_through [:browser]

    get "/auth/authorize", AuthController, :authorize
  end

  scope "/", PenguinMemoriesWeb do
    pipe_through [:oidc_callback]

    get "/openid_connect_redirect_uri", AuthController, :callback
    post "/openid_connect_redirect_uri", AuthController, :callback
  end

  scope "/", PenguinMemoriesWeb do
    pipe_through [:browser, :ensure_admin]

    live_dashboard "/dashboard",
      metrics: PenguinMemoriesWeb.Telemetry,
      ecto_repos: [PenguinMemories.Repo]
  end

  live_session :default, on_mount: PenguinMemoriesWeb.InitAssigns do
    scope "/images", PenguinMemoriesWeb do
      pipe_through [:browser, :static]
      get "/*path", FileNotFoundController, :index
    end

    scope "/", PenguinMemoriesWeb do
      pipe_through [:browser, :ensure_auth]

      get "/login", PageController, :login
    end

    scope "/", PenguinMemoriesWeb do
      pipe_through [:browser, :ensure_auth]
      live "/upload", UploadLive, :index
    end

    scope "/", PenguinMemoriesWeb do
      pipe_through [:browser]
      PenguinMemoriesWeb
      live "/", PageLive, :index
      post "/logout", PageController, :logout
      get "/file/:id/size/:size/", RedirectController, :photo
      get "/video/:id/size/:size/", RedirectController, :video
      live "/:type/", MainLive, :index
      live "/:type/:id/", MainLive, :index
    end
  end
end
