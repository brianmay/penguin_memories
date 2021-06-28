defmodule PenguinMemoriesWeb.ObjectDetailsLive do
  @moduledoc """
  Live view to display list of objects
  """
  use PenguinMemoriesWeb, :live_view

  alias Ecto.Changeset
  alias Elixir.Phoenix.LiveView.Socket

  alias PenguinMemories.Auth
  alias PenguinMemories.Database
  alias PenguinMemories.Database.Fields
  alias PenguinMemories.Database.Query
  alias PenguinMemories.Database.Types
  alias PenguinMemories.Photos
  alias PenguinMemories.Urls
  alias PenguinMemoriesWeb.FieldHelpers
  alias PenguinMemoriesWeb.IconHelpers
  alias PenguinMemoriesWeb.LiveRequest
  alias PenguinMemoriesWeb.Router.Helpers, as: Routes

  defmodule Request do
    @moduledoc """
    List of icons to display
    """
    @type selected_type :: PenguinMemoriesWeb.ObjectListLive.selected_type()

    @type t :: %__MODULE__{
            type: Database.object_type(),
            id: integer()
          }
    @enforce_keys [
      :type,
      :id
    ]
    defstruct type: nil,
              id: nil
  end

  @impl true
  @spec mount(map(), map(), Socket.t()) :: {:ok, Socket.t()}
  def mount(_params, _session, socket) do
    assigns = [
      filter: nil,
      request: nil,
      common: %LiveRequest{
        url: nil,
        host_url: nil,
        user: nil,
        big_id: nil,
        force_reload: nil
      },
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
      url: nil,
      title: nil
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
    url =
      socket.assigns.common.url
      |> Urls.url_merge(%{"big" => socket.id}, [])
      |> URI.to_string()

    socket = push_patch(socket, to: url)
    {:noreply, socket}
  end

  @impl true
  def handle_event("unbig", _params, %Socket{} = socket) do
    url =
      socket.assigns.common.url
      |> Urls.url_merge(%{}, ["big"])
      |> URI.to_string()

    socket = push_patch(socket, to: url)
    {:noreply, socket}
  end

  def handle_event("create", _params, %Socket{} = socket) do
    if Auth.can_edit(socket.assigns.common.user) and socket.assigns.request.type != Photos.Photo do
      handle_create(socket)
    else
      {:noreply, assign(socket, :error, "Permission denied")}
    end
  end

  @impl true
  def handle_event("edit", _params, %Socket{} = socket) do
    if Auth.can_edit(socket.assigns.common.user) do
      handle_edit(socket)
    else
      {:noreply, assign(socket, :error, "Permission denied")}
    end
  end

  @impl true
  def handle_event("delete", _params, %Socket{} = socket) do
    if Auth.can_edit(socket.assigns.common.user) do
      handle_delete(socket)
    else
      {:noreply, assign(socket, :error, "Permission denied")}
    end
  end

  @impl true
  def handle_event("validate", %{"object" => params}, %Socket{} = socket) do
    cond do
      not Auth.can_edit(socket.assigns.common.user) ->
        {:noreply, assign(socket, :error, "Permission denied")}

      not is_editing(socket.assigns) ->
        {:noreply, socket}

      true ->
        handle_validate(socket, params)
    end
  end

  @impl true
  def handle_event("save", %{"object" => params}, %Socket{} = socket) do
    cond do
      not Auth.can_edit(socket.assigns.common.user) ->
        {:noreply, assign(socket, :error, "Permission denied")}

      not is_editing(socket.assigns) ->
        {:noreply, socket}

      true ->
        handle_save(socket, params)
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

  def handle_info(
        {:parameters, %Query.Filter{} = filter, %LiveRequest{} = common, %Request{} = request},
        %Socket{} = socket
      ) do
    new_big = common.big_id == socket.id

    old = socket.assigns
    big_changed = old.big != new_big
    filter_changed = old.filter != filter
    user_changed = old.common.user != common.user
    request_changed = old.request != request

    assigns = [
      filter: filter,
      request: request,
      big: new_big
    ]

    socket =
      LiveRequest.apply_common(socket, common)
      |> assign(assigns)

    socket =
      if big_changed or user_changed or request_changed or common.force_reload do
        reload_details(socket)
      else
        socket
      end

    socket =
      if big_changed or filter_changed or request_changed or common.force_reload do
        reload_prev_next_icons(socket)
      else
        socket
      end

    {:noreply, socket}
  end

  @impl true
  def handle_info({:selected, id, value}, %Socket{} = socket) do
    assoc = Map.put(socket.assigns.assoc, id, value)
    socket = assign(socket, assoc: assoc)

    cond do
      not Auth.can_edit(socket.assigns.common.user) ->
        {:noreply, assign(socket, :error, "Permission denied")}

      not is_editing(socket.assigns) ->
        {:noreply, socket}

      true ->
        handle_validate(socket, socket.assigns.changeset.params)
    end
  end

  @spec is_editing(assigns :: map()) :: boolean()
  defp is_editing(assigns) do
    assigns.mode == :edit
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
    error =
      case Query.delete(socket.assigns.details.obj) do
        {:error, error} ->
          error

        :ok ->
          PenguinMemoriesWeb.Endpoint.broadcast("refresh", "refresh", %{})
          nil
      end

    {:noreply, assign(socket, error: error)}
  end

  @spec handle_validate(Socket.t(), map()) :: {:noreply, Socket.t()}
  def handle_validate(%Socket{} = socket, params) do
    changeset = get_edit_changeset(socket, params)
    {:noreply, assign(socket, changeset: changeset)}
  end

  @spec changeset_errors(Changeset.t() | list(Changeset.t())) :: list(String.t())
  defp changeset_errors(%Changeset{} = changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn
      {msg, opts} -> String.replace(msg, "%{count}", to_string(opts[:count]))
      msg -> msg
    end)
    |> Enum.map(fn {key, errors} ->
      Enum.map(errors, fn error -> "#{Atom.to_string(key)}: #{error}" end)
    end)
    |> List.flatten()
  end

  defp changeset_errors(changesets) do
    changesets
    |> Enum.map(fn changeset -> changeset_errors(changeset) end)
    |> List.flatten()
  end

  @spec add_nested_errors(Changeset.t()) :: Changeset.t()
  defp add_nested_errors(%Changeset{} = changeset) do
    Enum.map(changeset.changes, fn
      {key, changesets} -> {key, changeset_errors(changesets)}
    end)
    |> Enum.reduce(changeset, fn {key, errors}, changeset ->
      Enum.reduce(errors, changeset, fn error, changeset ->
        Changeset.add_error(changeset, key, error)
      end)
    end)
  end

  @spec handle_save(Socket.t(), map()) :: {:noreply, Socket.t()}
  defp handle_save(%Socket{} = socket, params) do
    changeset = get_edit_changeset(socket, params)

    {socket, assigns} =
      case Query.apply_edit_changeset(changeset) do
        {:error, changeset, error} ->
          changeset = add_nested_errors(changeset)

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
                type_name = Types.get_name!(socket.assigns.request.type)
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
    %Changeset{changeset | action: socket.assigns.action}
  end

  @spec get_prev_next_icons(
          cursor :: String.t(),
          filter :: Query.Filter.t(),
          type :: Database.object_type()
        ) :: {Query.Icon.t() | nil, Query.Icon.t() | nil}
  def get_prev_next_icons(cursor, filter, type) do
    prev_icon =
      case Query.get_prev_next_id(filter, cursor, nil, "thumb", type) do
        {:ok, icon} -> icon
        {:error, _} -> nil
      end

    next_icon =
      case Query.get_prev_next_id(filter, nil, cursor, "thumb", type) do
        {:ok, icon} -> icon
        {:error, _} -> nil
      end

    {prev_icon, next_icon}
  end

  @spec reload_prev_next_icons(Socket.t()) :: Socket.t()
  def reload_prev_next_icons(%Socket{} = socket) do
    {prev_icon, next_icon} =
      case socket.assigns.details do
        nil ->
          {nil, nil}

        details ->
          cursor = details.cursor
          filter = socket.assigns.filter
          type = socket.assigns.request.type
          get_prev_next_icons(cursor, filter, type)
      end

    assign(socket, prev_icon: prev_icon, next_icon: next_icon)
  end

  @spec reload_details(Socket.t()) :: Socket.t()
  def reload_details(%Socket{} = socket) do
    request = socket.assigns.request

    {icon_size, video_size} =
      case socket.assigns.big do
        false -> {"mid", "mid"}
        true -> {"large", "large"}
      end

    type = request.type
    id = request.id
    details = Query.get_details(id, icon_size, video_size, type)

    type_name = Query.get_single_name(type) |> String.capitalize()

    title =
      if details == nil do
        "#{type_name}: #{id}"
      else
        assign(socket, :title, "")
        name = details.icon.name
        "#{type_name}: #{name} (#{id})"
      end

    socket = assign(socket, details: details, title: title)
    send(socket.parent_pid, {:title, socket.id, title})

    if details == nil do
      assign(socket, :error, "Cannot load type #{inspect(type)} id #{id}")
    else
      assign(socket, :error, nil)
    end
  end

  @spec get_photo_url(Socket.t(), reference :: struct()) :: String.t() | nil
  defp get_photo_url(%Socket{}, %Photos.Photo{}), do: nil

  defp get_photo_url(%Socket{} = socket, %{__struct__: type, id: id}) do
    name = Types.get_name!(type)

    params = %{
      "reference" => "#{name}/#{id}"
    }

    Routes.main_path(socket, :index, "photo", params)
  end

  @spec to_int(String.t()) :: integer
  defp to_int(int) do
    {int, ""} = Integer.parse(int)
    int
  end
end
