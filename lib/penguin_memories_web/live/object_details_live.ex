defmodule PenguinMemoriesWeb.ObjectDetailsLive do
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
  alias PenguinMemoriesWeb.IconHelpers
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
      id: nil,
      big: nil,
      mode: :display,
      prev_icon: nil,
      next_icon: nil,
      error: nil,
      changeset: nil,
      edit_obj: nil,
      action: nil,
      details: nil,
      assoc: %{},
      url: nil
    ]

    socket = assign(socket, assigns)

    if connected?(socket) do
      send(socket.parent_pid, {:child_pid, socket.id, self()})
    end

    {:ok, socket}
  end

  @impl true
  @spec handle_event(String.t(), any, Phoenix.LiveView.Socket.t()) ::
          {:noreply, Phoenix.LiveView.Socket.t()}
  def handle_event("goto", params, socket) do
    %{"id" => id, "type" => type} = params
    id = to_int(id)
    {:ok, type} = Types.get_type_for_name(type)
    type_name = Types.get_name!(type)
    url = Routes.main_path(socket, :index, type_name, id)
    socket = push_redirect(socket, to: url)
    {:noreply, socket}
  end

  @impl true
  def handle_event("big", _params, %Socket{} = socket) do
    send(socket.root_pid, {:big, socket.id})
    {:noreply, socket}
  end

  @impl true
  def handle_event("unbig", _params, %Socket{} = socket) do
    send(socket.root_pid, {:big, nil})
    {:noreply, socket}
  end

  def handle_event("create", _params, %Socket{} = socket) do
    if Auth.can_edit(socket.assigns.user) and socket.assigns.type != Photos.Photo do
      handle_create(socket)
    else
      {:noreply, assign(socket, :error, "Permission denied")}
    end
  end

  @impl true
  def handle_event("edit", _params, %Socket{} = socket) do
    if Auth.can_edit(socket.assigns.user) do
      handle_edit(socket)
    else
      {:noreply, assign(socket, :error, "Permission denied")}
    end
  end

  @impl true
  def handle_event("delete", _params, %Socket{} = socket) do
    if Auth.can_edit(socket.assigns.user) do
      handle_delete(socket)
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
      mode: :display,
      changeset: nil,
      error: nil,
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
  def handle_info(
        {:parameters, type, id, url, %URI{} = host_uri, prev_icon, next_icon, big_value},
        socket
      ) do
    assigns = [
      type: type,
      id: id,
      prev_icon: prev_icon,
      next_icon: next_icon,
      big: big_value == socket.id,
      url: url
    ]

    socket = %Socket{socket | host_uri: host_uri}
    socket = assign(socket, assigns) |> reload()
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
    {assoc, changeset} = Query.get_create_child_changeset(socket.assigns.details.obj, %{}, %{})

    assigns = [
      mode: :edit,
      changeset: changeset,
      edit_object: changeset.data,
      action: :insert,
      assoc: assoc,
      error: nil
    ]

    {:noreply, assign(socket, assigns)}
  end

  @spec handle_edit(Socket.t()) :: {:noreply, Socket.t()}
  defp handle_edit(%Socket{} = socket) do
    changeset = Query.get_edit_changeset(socket.assigns.details.obj, %{}, %{})
    changeset = %{changeset | action: :update}

    assigns = [
      mode: :edit,
      changeset: changeset,
      edit_object: changeset.data,
      action: :update,
      assoc: %{},
      error: nil
    ]

    {:noreply, assign(socket, assigns)}
  end

  @spec handle_delete(Socket.t()) :: {:noreply, Socket.t()}
  defp handle_delete(%Socket{} = socket) do
    {socket, assigns} =
      case Query.delete(socket.assigns.details.obj) do
        {:error, error} ->
          assigns = [
            error: error
          ]

          {socket, assigns}

        :ok ->
          PenguinMemoriesWeb.Endpoint.broadcast("refresh", "refresh", %{})
          type_name = Types.get_name!(socket.assigns.type)
          url = Routes.main_path(socket, :index, type_name)
          socket = push_redirect(socket, to: url)

          assigns = [
            error: nil
          ]

          {socket, assigns}
      end

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

          socket =
            case socket.assigns.action do
              :insert ->
                type_name = Types.get_name!(socket.assigns.type)
                url = Routes.main_path(socket, :index, type_name, object.id)
                push_redirect(socket, to: url)

              _ ->
                socket
            end

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
    changeset = %{changeset | action: socket.assigns.action}

    changeset =
      Enum.reduce(socket.assigns.assoc, changeset, fn {key, value}, changeset ->
        Changeset.put_assoc(changeset, key, value)
      end)

    changeset
  end

  @spec reload(Socket.t()) :: Socket.t()
  def reload(%Socket{} = socket) do
    {icon_size, video_size} =
      case socket.assigns.big do
        false -> {"mid", "mid"}
        true -> {"large", "large"}
      end

    type = socket.assigns.type
    id = socket.assigns.id

    details = Query.get_details(id, icon_size, video_size, type)
    assign(socket, :details, details)
  end

  @spec get_photo_url(Socket.t(), reference :: struct()) :: String.t() | nil
  defp get_photo_url(%Socket{}, %Photos.Photo{}), do: nil

  defp get_photo_url(%Socket{} = socket, %{__struct__: type, id: id}) do
    name = Types.get_name!(type)

    params = %{
      reference: "#{name}/#{id}"
    }

    query = URI.encode_query(params)
    Routes.main_path(socket, :index, "photo") <> "?" <> query
  end

  @spec to_int(String.t()) :: integer
  defp to_int(int) do
    {int, ""} = Integer.parse(int)
    int
  end
end
