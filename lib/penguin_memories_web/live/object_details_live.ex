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
        current_user: nil,
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
  def handle_event("key", %{"key" => key}, %Socket{} = socket) do
    case key do
      "ArrowLeft" ->
        icon = socket.assigns.prev_icon

        if icon != nil do
          send(socket.parent_pid, {:select_object, icon.id})
        end

      "ArrowRight" ->
        icon = socket.assigns.next_icon

        if icon != nil do
          send(socket.parent_pid, {:select_object, icon.id})
        end

      _ ->
        nil
    end

    {:noreply, socket}
  end

  def handle_event("create", _params, %Socket{} = socket) do
    if Auth.can_edit(socket.assigns.common.current_user) and
         socket.assigns.request.type != Photos.Photo do
      handle_create(socket)
    else
      {:noreply, assign(socket, :error, "Permission denied")}
    end
  end

  @impl true
  def handle_event("edit", _params, %Socket{} = socket) do
    if Auth.can_edit(socket.assigns.common.current_user) do
      handle_edit(socket)
    else
      {:noreply, assign(socket, :error, "Permission denied")}
    end
  end

  @impl true
  def handle_event("delete", _params, %Socket{} = socket) do
    if Auth.can_edit(socket.assigns.common.current_user) do
      handle_delete(socket)
    else
      {:noreply, assign(socket, :error, "Permission denied")}
    end
  end

  @impl true
  def handle_event("validate", %{"object" => params}, %Socket{} = socket) do
    cond do
      not Auth.can_edit(socket.assigns.common.current_user) ->
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
      not Auth.can_edit(socket.assigns.common.current_user) ->
        {:noreply, assign(socket, :error, "Permission denied")}

      not is_editing(socket.assigns) ->
        {:noreply, socket}

      true ->
        handle_save(socket, params)
    end
  end

  @impl true
  def handle_event("cancel", _params, %Socket{} = socket) do
    socket = cancel_edit(socket)
    {:noreply, socket}
  end

  @impl true
  def handle_event("select-object", %{"id" => id}, socket) do
    id = to_int(id)
    send(socket.parent_pid, {:select_object, id})
    {:noreply, socket}
  end

  # credo:disable-for-next-line Credo.Check.Refactor.CyclomaticComplexity
  def handle_info(
        {:parameters, %Query.Filter{} = filter, %LiveRequest{} = common, %Request{} = request},
        %Socket{} = socket
      ) do
    new_big = common.big_id == socket.id

    old = socket.assigns
    big_changed = old.big != new_big
    filter_changed = old.filter != filter
    user_changed = old.common.current_user != common.current_user
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
      if request_changed do
        cancel_edit(socket)
      else
        socket
      end

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
      not Auth.can_edit(socket.assigns.common.current_user) ->
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

  @spec cancel_edit(socket :: Socket.t()) :: Socket.t()
  defp cancel_edit(%Socket{} = socket) do
    assigns = [
      mode: :display,
      changeset: nil,
      error: nil,
      edit_obj: nil
    ]

    assign(socket, assigns)
  end

  @spec handle_create(socket :: Socket.t()) :: {:noreply, Socket.t()}
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

  @spec handle_edit(socket :: Socket.t()) :: {:noreply, Socket.t()}
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

  @spec handle_delete(socket :: Socket.t()) :: {:noreply, Socket.t()}
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

  @spec handle_validate(socket :: Socket.t(), params :: map()) :: {:noreply, Socket.t()}
  def handle_validate(%Socket{} = socket, params) do
    changeset = get_edit_changeset(socket, params)
    {:noreply, assign(socket, changeset: changeset)}
  end

  @spec map_error(error :: String.t() | map()) :: list(String.t())
  defp map_error(%{} = error) do
    Enum.map(error, fn {key, error_list} ->
      Enum.map(error_list, fn value -> "#{key}: #{value}" end)
    end)
    |> List.flatten()
  end

  defp map_error(error) when is_binary(error) do
    error
  end

  @spec map_error_list(list :: list(String.t() | map())) :: list(String.t())
  defp map_error_list(list) do
    Enum.map(list, fn error -> map_error(error) end)
    |> List.flatten()
  end

  @spec add_nested_errors(changeset :: Changeset.t()) :: Changeset.t()
  defp add_nested_errors(%Changeset{} = changeset) do
    Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Enum.reduce(opts, msg, fn {key, value}, acc ->
        String.replace(acc, "%{#{key}}", to_string(value))
      end)
    end)
    |> Enum.map(fn {key, error} -> {key, map_error_list(error)} end)
    |> Enum.reduce(changeset, fn {key, errors}, changeset ->
      Enum.reduce(errors, changeset, fn error, changeset ->
        Changeset.add_error(changeset, key, error)
      end)
    end)
  end

  @spec handle_save(socket :: Socket.t(), params :: map()) :: {:noreply, Socket.t()}
  defp handle_save(%Socket{} = socket, params) do
    changeset = get_edit_changeset(socket, params)

    socket =
      case Query.apply_edit_changeset(changeset) do
        {:error, changeset, error} ->
          changeset = add_nested_errors(changeset)

          assigns = [
            changeset: changeset,
            error: error
          ]

          assign(socket, assigns)

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

          cancel_edit(socket)
      end

    {:noreply, socket}
  end

  @spec get_edit_changeset(socket :: Socket.t(), params :: map()) :: Changeset.t()
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

  @spec reload_prev_next_icons(socket :: Socket.t()) :: Socket.t()
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

  @spec reload_details(socket :: Socket.t()) :: Socket.t()
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

  @spec get_photo_url(socket :: Socket.t(), reference :: struct()) :: String.t() | nil
  defp get_photo_url(%Socket{}, %Photos.Photo{}), do: nil

  defp get_photo_url(%Socket{} = socket, %{__struct__: type, id: id}) do
    name = Types.get_name!(type)

    params = %{
      "reference" => "#{name}/#{id}"
    }

    Routes.main_path(socket, :index, "photo", params)
  end

  @spec get_big_url(socket :: Socket.t(), assigns :: map()) :: String.t()
  defp get_big_url(%Socket{} = socket, %{} = assigns) do
    assigns.common.url
    |> Urls.url_merge(%{"big" => socket.id}, [])
    |> URI.to_string()
  end

  @spec get_unbig_url(socket :: Socket.t(), assigns :: map()) :: String.t()
  defp get_unbig_url(%Socket{} = _socket, %{} = assigns) do
    assigns.common.url
    |> Urls.url_merge(%{}, ["big"])
    |> URI.to_string()
  end

  @spec to_int(String.t()) :: integer
  defp to_int(int) do
    {int, ""} = Integer.parse(int)
    int
  end
end
