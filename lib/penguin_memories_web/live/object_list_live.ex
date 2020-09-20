defmodule PenguinMemoriesWeb.ObjectListLive do
  use PenguinMemoriesWeb, :live_view

  alias PenguinMemories.Objects

  @impl true
  def mount(_params, _session, socket) do
    assigns = [
      selected_ids: MapSet.new(),
    ]

    PenguinMemoriesWeb.Endpoint.subscribe("refresh")
    {:ok, assign(socket, assigns)}
  end

  @spec uri_merge(URI.t(), %{required(String.t()) => String.t()}, list(String.t())) :: URI.t()
  defp uri_merge(uri, merge, delete) do
    query = case uri.query do
              nil -> %{}
              query -> URI.decode_query(query)
            end
    query = Map.merge(query, merge)
    query = Map.drop(query,
      delete)
    query = URI.encode_query(query)
    %URI{uri | query: query}
  end

  @impl true
  def handle_params(params, uri, socket) do
    requested_before_key = params["before"]
    requested_after_key = params["after"]

    type = Objects.get_for_type(params["type"])

    parsed_uri = URI.parse(uri)

    parent_id = cond do
      (id = params["id"]) != nil -> id
      (id = params["parent_id"]) != nil -> id
      true -> nil
    end

    params = case parent_id do
               nil -> params
               _ -> Map.put(params, "parent_id", parent_id)
             end

    assigns = [
      type: type,
      active: type.get_type_name(),
      parsed_uri: parsed_uri,
      requested_before_key: requested_before_key,
      requested_after_key: requested_after_key,
      parent_id: parent_id,
      search_spec: params,
      last_clicked_id: nil,
      show_selected: false,
    ]

    socket = socket
    |> assign(assigns)
    |> reload()

    {:noreply, socket}
  end

  def reload(socket) do
    type = socket.assigns.type
    parsed_uri = socket.assigns.parsed_uri
    requested_before_key = socket.assigns.requested_before_key
    requested_after_key = socket.assigns.requested_after_key
    search_spec = socket.assigns.search_spec

    parents = case socket.assigns.parent_id do
                nil -> []
                parent_id -> type.get_parents(parent_id)
              end

    show_ids = case socket.assigns.show_selected do
                 false -> nil
                 true -> socket.assigns.selected_ids
               end

    {icons, before_key, after_key, total_count} = type.get_page_icons(search_spec, show_ids, requested_before_key, requested_after_key)

    before_url = case before_key do
                   nil -> nil
                   key ->
                     parsed_uri
                     |> uri_merge(%{"before"=>key}, ["after"])
                     |> URI.to_string()
                 end

    after_url = case after_key do
                  nil -> nil
                  key ->
                    parsed_uri
                    |> uri_merge(%{"after"=>key}, ["before"])
                    |> URI.to_string()
                end

    assigns = [
      icons: icons,
      before_url: before_url,
      after_url: after_url,
      total_count: total_count,
      parents: parents,
    ]

    assign(socket, assigns)
  end

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
      state and not current  ->
        MapSet.put(mapset, id)
      true -> mapset
    end
  end

  defp num_selected(mapset) do
    MapSet.size(mapset)
  end

 defp toggle_range(mapset, icons, last_clicked_id, clicked_id) do
    new_state = MapSet.member?(mapset, last_clicked_id)

    {state, new_mapset} = Enum.reduce(icons, {0, mapset}, fn
      icon, {0, mapset} ->
        cond do
          icon.id == last_clicked_id ->
            {1, set(mapset, icon.id, new_state)}
          icon.id == clicked_id ->
            {1, set(mapset, icon.id, new_state)}
          true -> {0, mapset}
        end
      icon, {1, mapset} ->
        cond do
          icon.id == last_clicked_id ->
            {2, set(mapset, icon.id, new_state)}
          icon.id == clicked_id ->
            {2, set(mapset, icon.id, new_state)}
          true -> {1, set(mapset, icon.id, new_state)}
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

  @impl true
  def handle_event("parent", params, socket) do
    %{"id" => id} = params
    type_name = socket.assigns.type.get_type_name()
    url = Routes.object_list_path(socket, :index, type_name, id)
    socket = push_patch(socket, to: url)
    {:noreply, socket}
  end

  @impl true
  def handle_event("select", params, socket) do
    %{"id" => id, "ctrlKey" => ctrlKey, "shiftKey" => shiftKey, "altKey" => altKey} = params
    {clicked_id, ""} = Integer.parse(id)

    {selected_ids, socket} = cond do
      ctrlKey ->
        s = toggle(socket.assigns.selected_ids, clicked_id)
        {s, socket}

      shiftKey ->
        s = toggle_range(socket.assigns.selected_ids, socket.assigns.icons, socket.assigns.last_clicked_id, clicked_id)
        {s, socket}

      altKey ->
        type_name = socket.assigns.type.get_type_name()
        url = Routes.object_list_path(socket, :index, type_name, id)
        socket = push_patch(socket, to: url)
        {socket.assigns.selected_ids, socket}

      true ->
        {MapSet.new([clicked_id]), socket}
    end

    assigns = [
      selected_ids: selected_ids,
      last_clicked_id: clicked_id,
    ]

    {:noreply, assign(socket, assigns)}
  end

  @impl true
  def handle_event("show-selected", _params, socket) do
    {:noreply, assign(socket, show_selected: true) |> reload() }
  end

  @impl true
  def handle_event("select-none", _params, socket) do
    {:noreply, assign(socket, selected_ids: MapSet.new()) |> reload() }
  end

  @impl true
  def handle_event("show-all", _params, socket) do
    {:noreply, assign(socket, show_selected: false) |> reload() }
  end

  defp icon_classes(icon, selected_ids, last_clicked_id) do
    result = []

    result = cond do
      last_clicked_id == icon.id -> ["last_clicked" | result]
      true -> result
    end

    result = cond do
      MapSet.member?(selected_ids, icon.id) -> ["selected" | result]
      true -> result
    end

    result
  end

  @impl true
  def handle_info(value, socket) do
    IO.inspect(value)
    socket = reload(socket)
    {:noreply, socket}
  end

end
