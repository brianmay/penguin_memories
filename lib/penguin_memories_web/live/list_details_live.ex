defmodule PenguinMemoriesWeb.ListDetailsLive do
  @moduledoc """
  Live view to display list of objects
  """
  use PenguinMemoriesWeb, :live_view

  alias Ecto.Changeset
  alias Elixir.Phoenix.LiveView.Socket

  alias PenguinMemories.Accounts.User
  alias PenguinMemories.Auth
  alias PenguinMemories.Database.Fields
  alias PenguinMemories.Database.Query
  alias PenguinMemories.Database.Types
  alias PenguinMemories.Photos
  alias PenguinMemoriesWeb.FieldHelpers
  alias PenguinMemoriesWeb.Router.Helpers, as: Routes

  @impl true
  @spec mount(map(), map(), Socket.t()) :: {:ok, Socket.t()}
  def mount(_params, session, socket) do
    user =
      case Auth.load_user(session) do
        {:ok, %User{} = user} -> user
        :not_logged_in -> nil
      end

    assigns = [
      user: user,
      type: nil,
      error: nil,
      changeset: nil,
      edit_obj: nil,
      assoc: %{}
    ]

    socket = assign(socket, assigns)

    if connected?(socket) do
      send(socket.parent_pid, {:child_pid, socket.id, self()})
    end

    {:ok, socket}
  end

  def handle_event("create", _params, %Socket{} = socket) do
    if Auth.can_edit(socket.assigns.user) do
      handle_create(socket)
    else
      {:noreply, assign(socket, :error, "Permission denied")}
    end
  end

  @impl true
  def handle_event("validate", %{"object" => params}, %Socket{} = socket) do
    if Auth.can_edit(socket.assigns.user) do
      handle_validate(socket, params)
    else
      {:noreply, assign(socket, :error, "Permission denied")}
    end
  end

  @impl true
  def handle_event("save", %{"object" => params}, %Socket{} = socket) do
    if Auth.can_edit(socket.assigns.user) do
      handle_save(socket, params)
    else
      {:noreply, assign(socket, :error, "Permission denied")}
    end
  end

  @impl true
  def handle_event("cancel", _params, %Socket{} = socket) do
    assigns = [
      error: nil,
      changeset: nil,
      edit_obj: nil
    ]

    {:noreply, assign(socket, assigns)}
  end

  @impl true
  def handle_event("select-object", %{"id" => id}, socket) do
    id = to_int(id)
    send(socket.parent_pid, {:select_object, id})
    {:noreply, socket}
  end

  @impl true
  def handle_info({:parameters, type}, socket) do
    socket =
      if socket.assigns.type != type do
        assign(socket, type: type) |> reload()
      else
        socket
      end

    {:noreply, socket}
  end

  @impl true
  def handle_info({:selected, id, value}, %Socket{} = socket) do
    assoc = Map.put(socket.assigns.assoc, id, value)
    socket = assign(socket, assoc: assoc)
    {:noreply, socket}
  end

  @spec handle_create(Socket.t()) :: {:noreply, Socket.t()}
  defp handle_create(%Socket{} = socket) do
    type = socket.assigns.type
    changeset = Query.get_edit_changeset(struct(type), %{}, %{})

    assigns = [
      error: nil,
      changeset: changeset,
      edit_object: changeset.data,
      assoc: %{}
    ]

    {:noreply, assign(socket, assigns)}
  end

  @spec handle_validate(Socket.t(), map()) :: {:noreply, Socket.t()}
  def handle_validate(%Socket{} = socket, params) do
    changeset = get_edit_changeset(socket, params)

    assigns = [
      changeset: changeset
    ]

    {:noreply, assign(socket, assigns)}
  end

  @spec handle_save(Socket.t(), map()) :: {:noreply, Socket.t()}
  defp handle_save(%Socket{} = socket, params) do
    changeset = get_edit_changeset(socket, params)

    {socket, assigns} =
      case Query.apply_edit_changeset(changeset) do
        {:error, changeset, error} ->
          assigns = [
            changeset: changeset,
            error: error
          ]

          {socket, assigns}

        {:ok, object} ->
          PenguinMemoriesWeb.Endpoint.broadcast("refresh", "refresh", %{})

          type_name = Types.get_name!(socket.assigns.type)
          url = Routes.main_path(socket, :index, type_name, object.id)
          socket = push_redirect(socket, to: url)

          assigns = [
            mode: :display,
            changeset: nil,
            error: nil
          ]

          {socket, assigns}
      end

    {:noreply, assign(socket, assigns)}
  end

  @spec get_edit_changeset(Socket.t(), map()) :: Changeset.t()
  defp get_edit_changeset(%Socket{} = socket, params) do
    changeset = Query.get_edit_changeset(socket.assigns.edit_object, params, socket.assigns.assoc)
    changeset = %{changeset | action: :insert}

    changeset =
      Enum.reduce(socket.assigns.assoc, changeset, fn {key, value}, changeset ->
        Changeset.put_assoc(changeset, key, value)
      end)

    changeset
  end

  @spec reload(Socket.t()) :: Socket.t()
  def reload(%Socket{} = socket) do
    assigns = [
      error: nil,
      changeset: nil,
      edit_obj: nil
    ]

    assign(socket, assigns)
  end

  @spec to_int(String.t()) :: integer
  defp to_int(int) do
    {int, ""} = Integer.parse(int)
    int
  end
end
