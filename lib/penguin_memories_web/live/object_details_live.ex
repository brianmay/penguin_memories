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
  alias PenguinMemories.Repo
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
            id: integer(),
            keyboard_nav: boolean()
          }
    @enforce_keys [
      :type,
      :id
    ]
    defstruct type: nil,
              id: nil,
              keyboard_nav: false
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
      success: nil,
      changeset: nil,
      edit_obj: nil,
      action: nil,
      details: nil,
      assoc: %{},
      url: nil,
      title: nil,
      delete_error: nil
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
    socket = push_navigate(socket, to: url)
    {:noreply, socket}
  end

  @impl true
  def handle_event("key", %{"key" => "Escape"}, %Socket{} = socket) do
    if socket.assigns.big do
      url = get_back_url(socket, socket.assigns)
      {:noreply, push_patch(socket, to: url)}
    else
      {:noreply, socket}
    end
  end

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
      if socket.assigns.request.type == Photos.Photo do
        handle_delete(socket)
      else
        id = socket.assigns.details.obj.id
        type = socket.assigns.request.type

        delete_error =
          case Query.can_delete?(id, type) do
            :yes -> nil
            {:no, reason} -> reason
          end

        {:noreply, assign(socket, mode: :confirm_delete, delete_error: delete_error)}
      end
    else
      {:noreply, assign(socket, :error, "Permission denied")}
    end
  end

  @impl true
  def handle_event("delete-confirm", _params, %Socket{} = socket) do
    if Auth.can_edit(socket.assigns.common.current_user) do
      handle_delete(socket)
    else
      {:noreply, assign(socket, :error, "Permission denied")}
    end
  end

  @impl true
  def handle_event("undelete", _params, %Socket{} = socket) do
    if Auth.can_edit(socket.assigns.common.current_user) do
      handle_undelete(socket)
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

  @impl true
  def handle_event("add_parent", %{"id" => _parent_id_string}, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event(
        "set-cover-photo",
        %{"parent-type" => type_name, "parent-id" => parent_id},
        socket
      ) do
    if Auth.can_edit(socket.assigns.common.current_user) do
      with {:ok, parent_type} <- Types.get_type_for_name(type_name),
           {parent_id, ""} <- Integer.parse(parent_id),
           {:ok, _updated} <-
             Query.set_cover_photo(parent_type, parent_id, socket.assigns.details.obj.id) do
        PenguinMemoriesWeb.Endpoint.broadcast("refresh", "refresh", %{})
        {:noreply, assign(socket, success: "Cover photo updated successfully", error: nil)}
      else
        {:error, reason} ->
          {:noreply, assign(socket, error: "Failed to set cover photo: #{reason}", success: nil)}

        _error ->
          {:noreply, assign(socket, error: "Invalid parameters", success: nil)}
      end
    else
      {:noreply, assign(socket, error: "Permission denied", success: nil)}
    end
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
        # For album_parents_edit changes, we need to trigger validation carefully
        # to update the changeset without causing page reloads

        # IMPORTANT: Use the socket that already has the updated assoc
        changeset = get_edit_changeset(socket, %{})

        {:noreply, assign(socket, changeset: changeset)}
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
      edit_obj: nil,
      delete_error: nil
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
    case Query.delete(socket.assigns.details.obj) do
      {:error, error} ->
        {:noreply, assign(socket, error: error, mode: :display)}

      :ok ->
        PenguinMemoriesWeb.Endpoint.broadcast("refresh", "refresh", %{})
        type = socket.assigns.request.type

        if type == Photos.Photo do
          {:noreply, assign(socket, error: nil, success: nil, mode: :display)}
        else
          type_name = Types.get_name!(type)
          url = Routes.main_path(socket, :index, type_name)
          {:noreply, push_navigate(socket, to: url)}
        end
    end
  end

  @spec handle_undelete(socket :: Socket.t()) :: {:noreply, Socket.t()}
  defp handle_undelete(%Socket{} = socket) do
    changeset = Query.get_edit_changeset(socket.assigns.details.obj, %{"action" => "auto"}, %{})

    socket =
      case Query.apply_edit_changeset(changeset) do
        {:error, _changeset, error} ->
          assign(socket, error: error)

        {:ok, _object} ->
          PenguinMemoriesWeb.Endpoint.broadcast("refresh", "refresh", %{})
          socket
      end

    {:noreply, socket}
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
                push_navigate(socket, to: url)

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
        "#{type_name}: #{name}"
      end

    socket = assign(socket, details: details, title: title)
    send(socket.parent_pid, {:title, socket.id, title})

    if details == nil do
      assign(socket, error: "Cannot load type #{inspect(type)} id #{id}", success: nil)
    else
      assign(socket, error: nil, success: nil)
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

  @spec get_back_url(socket :: Socket.t(), assigns :: map()) :: String.t()
  defp get_back_url(%Socket{} = _socket, %{} = assigns) do
    assigns.common.url
    |> Urls.url_merge(%{}, ["big", "p_selected", "obj_selected"])
    |> URI.to_string()
  end

  @spec to_int(String.t()) :: integer
  defp to_int(int) do
    {int, ""} = Integer.parse(int)
    int
  end

  @spec get_parent_context(assigns :: map()) :: {Types.object_type(), integer()} | nil
  defp get_parent_context(%{filter: %Query.Filter{reference: {parent_type, parent_id}}})
       when parent_type in [
              PenguinMemories.Photos.Album,
              PenguinMemories.Photos.Category,
              PenguinMemories.Photos.Place,
              PenguinMemories.Photos.Person
            ] do
    {parent_type, parent_id}
  end

  defp get_parent_context(_), do: nil

  @spec get_parent_details_from_context(assigns :: map()) :: {String.t(), String.t()} | nil
  defp get_parent_details_from_context(assigns) do
    case get_parent_context(assigns) do
      {parent_type, parent_id} ->
        # Look for the parent in the existing parents data
        # Handle both regular parents format and multiple_trails format
        parent_icon =
          case assigns.details.parents do
            {:multiple_trails, trails} ->
              # Extract all icons from all trails
              trails
              |> Enum.flat_map(fn trail ->
                Enum.flat_map(trail, fn {_position, icons} -> icons end)
              end)
              |> Enum.find(fn icon -> icon.type == parent_type and icon.id == parent_id end)

            parents when is_list(parents) ->
              # Regular format: list of {position, icons} tuples
              parents
              |> Enum.flat_map(fn {_position, icons} -> icons end)
              |> Enum.find(fn icon -> icon.type == parent_type and icon.id == parent_id end)

            _ ->
              # Unexpected format, skip search
              nil
          end

        if parent_icon do
          type_name =
            case parent_type do
              PenguinMemories.Photos.Album -> "Album"
              PenguinMemories.Photos.Category -> "Category"
              PenguinMemories.Photos.Place -> "Place"
              PenguinMemories.Photos.Person -> "Person"
            end

          {type_name, parent_icon.name}
        else
          # Fallback to database query if not found in parents
          get_parent_details_from_db(parent_type, parent_id)
        end

      nil ->
        nil
    end
  end

  @spec get_confirmation_message(assigns :: map()) :: String.t()
  defp get_confirmation_message(assigns) do
    case get_parent_details_from_context(assigns) do
      {type_name, parent_name} ->
        "Set this photo as the cover photo for #{type_name}: '#{parent_name}'?"

      nil ->
        "Set this photo as the cover photo?"
    end
  end

  @spec photo_has_coordinates?(assigns :: map()) :: boolean()
  defp photo_has_coordinates?(assigns) do
    case assigns do
      %{
        request: %{type: PenguinMemories.Photos.Photo},
        details: %{obj: photo},
        common: %{current_user: user}
      } ->
        Auth.can_see_geo_point(user, photo.point)

      _ ->
        false
    end
  end

  @spec get_photo_coordinates(assigns :: map()) :: {float(), float()} | nil
  defp get_photo_coordinates(assigns) do
    case assigns do
      %{request: %{type: PenguinMemories.Photos.Photo}, details: %{obj: photo}} ->
        case photo.point do
          # PostGIS: x=lat, y=lng; we need {lat, lng}
          %Geo.Point{coordinates: {x, y}} -> {x, y}
          _ -> nil
        end

      _ ->
        nil
    end
  end

  @spec get_parent_details_from_db(parent_type :: Types.object_type(), parent_id :: integer()) ::
          {String.t(), String.t()} | nil
  defp get_parent_details_from_db(parent_type, parent_id) do
    case Repo.get(parent_type, parent_id) do
      nil ->
        nil

      parent ->
        type_name =
          case parent_type do
            PenguinMemories.Photos.Album -> "Album"
            PenguinMemories.Photos.Category -> "Category"
            PenguinMemories.Photos.Place -> "Place"
            PenguinMemories.Photos.Person -> "Person"
          end

        {type_name, parent.name}
    end
  end

  @spec group_person_parents_by_level([{integer(), [any()]}]) :: [
          {String.t(), [{integer(), [any()]}]}
        ]
  defp group_person_parents_by_level(parents) do
    parents
    |> Enum.group_by(fn {position, _icons} ->
      case position do
        1 -> "Parents"
        2 -> "Grandparents"
        3 -> "Great-Grandparents"
        4 -> "Great-Great-Grandparents"
        n when n >= 5 -> "#{n - 2}x Great-Grandparents"
      end
    end)
    |> Enum.map(fn {level_name, parent_group} -> {level_name, parent_group} end)
    |> Enum.sort_by(fn {_level_name, [{position, _icons} | _]} -> position end)
  end
end
