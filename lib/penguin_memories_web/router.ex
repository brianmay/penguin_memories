defmodule PenguinMemoriesWeb.Router do
  use PenguinMemoriesWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_flash
    plug :protect_from_forgery
    plug :put_secure_browser_headers
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

    get "/", PageController, :index
    get "/login", SessionController, :new
    post "/login", SessionController, :login
    post "/logout", SessionController, :logout
  end

  scope "/", PenguinMemoriesWeb do
    pipe_through [:browser, :auth, :ensure_auth]
  end

  scope "/", PenguinMemoriesWeb do
    pipe_through [:browser, :auth, :ensure_admin]

    resources "/users", UserController
    get "/users/:id/password", UserController, :password_edit
    put "/users/:id/password", UserController, :password_update
  end

  # Other scopes may use custom stacks.
  # scope "/api", PenguinMemoriesWeb do
  #   pipe_through :api
  # end

  # Enables LiveDashboard only for development
  #
  # If you want to use the LiveDashboard in production, you should put
  # it behind authentication and allow only admins to access it.
  # If your application does not have an admins-only section yet,
  # you can use Plug.BasicAuth to set up some basic authentication
  # as long as you are also using SSL (which you should anyway).
  if Mix.env() in [:dev, :test] do
    import Phoenix.LiveDashboard.Router

    scope "/" do
      pipe_through :browser
      live_dashboard "/dashboard", metrics: PenguinMemoriesWeb.Telemetry
    end
  end
end
