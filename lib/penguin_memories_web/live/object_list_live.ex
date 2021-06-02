defmodule PenguinMemoriesWeb.ObjectListLive do
  @moduledoc """
  Live view to display list of objects
  """
  use PenguinMemoriesWeb, :live_view

  alias Elixir.Phoenix.LiveView.Socket

  alias PenguinMemories.Database
  alias PenguinMemories.Database.Query
  alias PenguinMemories.Database.Types
  alias PenguinMemories.Loaders
  alias PenguinMemories.Urls

  @impl true
  @spec mount(map(), map(), Socket.t()) :: {:ok, Socket.t()}
  def mount(_params, _session, socket) do
    assigns = [
      request: nil,
      url: nil,
      selected_ids: MapSet.new(),
      last_clicked_id: nil,
      response: nil,
      selected_pid: nil,
      update_pid: nil
    ]

    socket = assign(socket, assigns)

    if connected?(socket) do
      send(socket.parent_pid, {:child_pid, socket.id, self()})
    end

    {:ok, socket}
  end

  @impl true
  def handle_event("select", params, socket) do
    %{"id" => clicked_id, "ctrlKey" => ctrl_key, "shiftKey" => shift_key, "altKey" => alt_key} =
      params

    clicked_id = to_int(clicked_id)

    {selected_ids, socket} =
      cond do
        ctrl_key ->
          s = toggle(socket.assigns.selected_ids, clicked_id)
          {s, socket}

        shift_key ->
          s =
            toggle_range(
              socket.assigns.selected_ids,
              socket.assigns.response.icons,
              socket.assigns.last_clicked_id,
              clicked_id
            )

          {s, socket}

        alt_key ->
          type_name = Types.get_name!(socket.assigns.request.type)
          url = Routes.main_path(socket, :index, type_name, clicked_id)
          socket = push_patch(socket, to: url)
          {socket.assigns.selected_ids, socket}

        true ->
          {MapSet.new([clicked_id]), socket}
      end

    assigns = [
      selected_ids: selected_ids,
      last_clicked_id: clicked_id
    ]

    socket =
      socket
      |> assign(assigns)
      |> reload()

    {:noreply, socket}
  end

  @impl true
  def handle_event("show-selected", _params, socket) do
    name = socket.assigns.request.show_selected_name
    before_name = socket.assigns.request.before_name
    after_name = socket.assigns.request.after_name

    url =
      socket.assigns.url
      |> Urls.url_merge(%{name => true}, [before_name, after_name])
      |> URI.to_string()

    socket = push_patch(socket, to: url)
    {:noreply, socket}
  end

  @impl true
  def handle_event("show-all", _params, socket) do
    name = socket.assigns.request.show_selected_name

    url =
      socket.assigns.url
      |> Urls.url_merge(%{}, [name])
      |> URI.to_string()

    socket = push_patch(socket, to: url)
    {:noreply, socket}
  end

  @impl true
  def handle_event("select-none", _params, socket) do
    {:noreply, socket |> assign(selected_ids: MapSet.new()) |> reload()}
  end

  @impl true
  def handle_event("select-all", _params, socket) do
    {:noreply, socket |> assign(selected_ids: :all) |> reload()}
  end

  @impl true
  def handle_info(
        {:parameters, %Loaders.ListRequest{} = request, %URI{} = url, %URI{} = host_uri},
        socket
      ) do
    assigns = [
      request: request,
      url: url
    ]

    socket = %Socket{socket | host_uri: host_uri}
    socket = assign(socket, assigns) |> reload()
    {:noreply, socket}
  end

  @impl true
  def handle_info({:select_object, id}, socket) do
    socket = assign(socket, selected_ids: MapSet.new([id])) |> reload()
    {:noreply, socket}
  end

  @impl true
  def handle_info({:child_pid, "selected", pid}, socket) do
    socket = assign(socket, selected_pid: pid)
    :ok = notify_selected_child(socket)
    {:noreply, socket}
  end

  @impl true
  def handle_info({:child_pid, "update", pid}, socket) do
    socket = assign(socket, update_pid: pid)
    :ok = notify_update_child(socket)
    {:noreply, socket}
  end

  @spec get_prev_next_icons(
          selection_id :: integer,
          filter :: Query.Filter.t(),
          type :: Database.object_type()
        ) :: {Query.Icon.t() | nil, Query.Icon.t() | nil}
  def get_prev_next_icons(selection_id, filter, type) do
    case Query.get_cursor_by_id(selection_id, type) do
      nil ->
        {nil, nil}

      cursor ->
        prev_icon = Query.get_prev_next_id(filter, cursor, nil, "thumb", type)
        next_icon = Query.get_prev_next_id(filter, nil, cursor, "thumb", type)
        {prev_icon, next_icon}
    end
  end

  @spec notify_update_child(Socket.t()) :: :ok
  defp notify_update_child(%Socket{} = socket) do
    if socket.assigns.update_pid != nil do
      request = socket.assigns.request
      type = request.type
      filter = get_update_filter(socket.assigns)
      pid = socket.assigns.update_pid
      send(pid, {:parameters, filter, type})
    end

    :ok
  end

  @spec notify_selected_child(Socket.t()) :: :ok
  defp notify_selected_child(%Socket{} = socket) do
    if socket.assigns.selected_pid != nil do
      case get_single_selection(socket.assigns.selected_ids) do
        nil ->
          :ok

        selection_id ->
          request = socket.assigns.request
          type = request.type
          filter = get_filter(socket.assigns)
          {prev_icon, next_icon} = get_prev_next_icons(selection_id, filter, type)

          pid = socket.assigns.selected_pid

          send(
            pid,
            {:parameters, type, selection_id, socket.assigns.url, socket.host_uri, prev_icon,
             next_icon, request.big_value}
          )
      end
    end

    :ok
  end

  @spec count_selections(selected_ids :: MapSet.t() | :all) :: integer() | :infinity
  def count_selections(:all), do: :infinity
  def count_selections(selected_ids), do: MapSet.size(selected_ids)

  @spec get_single_selection(selected_ids :: MapSet.t()) :: integer() | nil
  def get_single_selection(selected_ids) do
    case count_selections(selected_ids) do
      :infinity ->
        nil

      1 ->
        [id] = MapSet.to_list(selected_ids)
        id

      _ ->
        nil
    end
  end

  @spec reload(Socket.t()) :: Socket.t()
  defp reload(%Socket{} = socket) do
    :ok = notify_selected_child(socket)
    :ok = notify_update_child(socket)

    request = get_request(socket.assigns)
    response = Loaders.load_objects(request, socket.assigns.url)
    assign(socket, response: response)
  end

  @spec icon_classes(Query.Icon.t(), MapSet.t(), integer) :: list(String.t())
  defp icon_classes(%Query.Icon{} = icon, selected_ids, last_clicked_id) do
    result = []

    result =
      cond do
        last_clicked_id == icon.id -> ["last_clicked" | result]
        true -> result
      end

    result =
      cond do
        selected_ids == :all -> ["selected" | result]
        MapSet.member?(selected_ids, icon.id) -> ["selected" | result]
        true -> result
      end

    result
  end

  @spec toggle(mapset :: MapSet.t(), id :: integer()) :: MapSet.t()
  defp toggle(mapset, id) do
    cond do
      MapSet.member?(mapset, id) ->
        MapSet.delete(mapset, id)

      true ->
        MapSet.put(mapset, id)
    end
  end

  defp set(mapset, id, state) do
    current = MapSet.member?(mapset, id)

    cond do
      not state and current ->
        MapSet.delete(mapset, id)

      state and not current ->
        MapSet.put(mapset, id)

      true ->
        mapset
    end
  end

  @spec get_update_filter(assigns :: map()) :: map()
  defp get_update_filter(assigns) do
    case assigns.selected_ids do
      :all -> assigns.request.filter
      selected_ids -> %Query.Filter{ids: selected_ids}
    end
  end

  @spec get_filter(assigns :: map()) :: map()
  defp get_filter(assigns) do
    case assigns.request.show_selected_value do
      false -> assigns.request.filter
      true -> get_update_filter(assigns)
    end
  end

  @spec get_request(assigns :: map()) :: Loaders.ListRequest.t()
  def get_request(assigns) do
    filter = get_filter(assigns)
    %Loaders.ListRequest{assigns.request | filter: filter}
  end

  @spec toggle_range(
          mapset :: MapSet.t(),
          icons :: Query.Icon.t(),
          last_clicked_id :: integer(),
          clicked_id :: integer
        ) :: MapSet.t()
  # credo:disable-for-next-line Credo.Check.Refactor.CyclomaticComplexity
  defp toggle_range(mapset, icons, last_clicked_id, clicked_id) do
    new_state = MapSet.member?(mapset, last_clicked_id)

    {state, new_mapset} =
      Enum.reduce(icons, {0, mapset}, fn
        icon, {0, mapset} ->
          cond do
            icon.id == last_clicked_id ->
              {1, set(mapset, icon.id, new_state)}

            icon.id == clicked_id ->
              {1, set(mapset, icon.id, new_state)}

            true ->
              {0, mapset}
          end

        icon, {1, mapset} ->
          cond do
            icon.id == last_clicked_id ->
              {2, set(mapset, icon.id, new_state)}

            icon.id == clicked_id ->
              {2, set(mapset, icon.id, new_state)}

            true ->
              {1, set(mapset, icon.id, new_state)}
          end

        _, {2, mapset} ->
          {2, mapset}
      end)

    case state do
      0 -> mapset
      1 -> mapset
      2 -> new_mapset
    end
  end

  @spec to_int(String.t()) :: integer
  def to_int(int) do
    {int, ""} = Integer.parse(int)
    int
  end
end
