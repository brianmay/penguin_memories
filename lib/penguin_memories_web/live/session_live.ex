defmodule PenguinMemoriesWeb.SessionLive do
  use PenguinMemoriesWeb, :live_view

  alias PenguinMemories.{Accounts, Accounts.User}
  alias PenguinMemoriesWeb.Router.Helpers, as: Routes

  @impl true
  def mount(_params, _session, socket) do
    changeset = Accounts.login_user(%User{})

    socket = assign(
        socket,
        changeset: changeset,
        action: Routes.session_path(socket, :login),
        active: "session"
    )

    {:ok, socket}
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

