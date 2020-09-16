defmodule PenguinMemoriesWeb.Router do
  use PenguinMemoriesWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, {PenguinMemoriesWeb.LayoutView, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug :put_layout, {PenguinMemoriesWeb.LayoutView, :live}
  end

  pipeline :auth do
    plug PenguinMemories.Accounts.Pipeline
  end

  # We use ensure_auth to fail if there is no one logged in
  pipeline :ensure_auth do
    plug Guardian.Plug.EnsureAuthenticated
  end

  pipeline :ensure_admin do
    plug Guardian.Plug.EnsureAuthenticated
    plug PenguinMemories.Accounts.CheckAdmin
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", PenguinMemoriesWeb do
    pipe_through [:browser, :auth]

    live "/", PageLive, :index
    live "/login", SessionLive, :login
    post "/login", SessionController, :login
    post "/logout", SessionController, :logout
    live "/:type/", ObjectListLive, :index
    live "/:type/:id/", ObjectListLive, :index_id
  end

  scope "/", PenguinMemoriesWeb do
    pipe_through [:browser, :auth, :ensure_auth]
  end

  import Phoenix.LiveDashboard.Router

  scope "/", PenguinMemoriesWeb do
    pipe_through [:browser, :auth, :ensure_admin]

    resources "/users", UserController
    get "/users/:id/password", UserController, :password_edit
    put "/users/:id/password", UserController, :password_update
    live_dashboard "/dashboard", metrics: PenguinMemoriesWeb.Telemetry
  end

  # Other scopes may use custom stacks.
  # scope "/api", PenguinMemoriesWeb do
  #   pipe_through :api
  # end
end
