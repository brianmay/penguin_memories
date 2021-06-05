defmodule PenguinMemoriesWeb.SessionLive do
  @moduledoc "Login/logout of a session"
  use PenguinMemoriesWeb, :live_view

  alias PenguinMemories.{Accounts, Accounts.User}
  alias PenguinMemories.Urls
  alias PenguinMemoriesWeb.Router.Helpers, as: Routes

  @impl true
  def mount(params, session, socket) do
    socket = assign_defaults(socket, session)

    changeset = Accounts.login_user(%User{})
    next = params["next"]

    socket =
      assign(
        socket,
        changeset: changeset,
        action: Routes.session_path(socket, :login, next: next),
        active: "session",
        page_title: "Login"
      )

    {:ok, socket}
  end

  @impl true
  def handle_params(_params, uri, socket) do
    url = Urls.parse_url(uri)
    socket = assign(socket, url: url)
    {:noreply, socket}
  end

  @impl true
  def render(assigns) do
    PenguinMemoriesWeb.SessionView.render("new.html", assigns)
  end

  @impl true
  def handle_event("validate", %{"user" => user_params}, socket) do
    changeset = Accounts.login_user(%User{}, user_params)
    changeset = %{changeset | action: :login}
    {:noreply, assign(socket, changeset: changeset)}
  end
end
