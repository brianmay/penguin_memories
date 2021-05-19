defmodule PenguinMemoriesWeb.ObjectListLive do
  @moduledoc """
  Live view to display list of objects
  """
  use PenguinMemoriesWeb, :live_view

  alias Elixir.Phoenix.LiveView.Socket
  alias PenguinMemories.Auth
  alias PenguinMemories.Database.Query
  alias PenguinMemories.Database.Query.Filter
  alias PenguinMemories.Database.Query.Icon
  alias PenguinMemories.Database.Types

  @impl true
  @spec mount(map(), map(), Socket.t()) :: {:ok, Socket.t()}
  def mount(_params, session, socket) do
    assigns = [
      selected_ids: MapSet.new()
    ]

    assigns =
      case Auth.load_user(session) do
        {:ok, user} ->
          [{:user, user} | assigns]

        {:error, error} ->
          [{:error, "There was an error logging the user in: #{inspect(error)}"} | assigns]

        :not_logged_in ->
          assigns
      end
      |> Keyword.put_new(:error, nil)
      |> Keyword.put_new(:user, nil)

    PenguinMemoriesWeb.Endpoint.subscribe("refresh")
    {:ok, assign(socket, assigns)}
  end

  @spec uri_merge(URI.t(), %{required(String.t()) => String.t()}, list(String.t())) :: URI.t()
  defp uri_merge(uri, merge, delete) do
    query =
      case uri.query do
        nil -> %{}
        query -> URI.decode_query(query)
      end

    query = Map.drop(query, delete)
    query = Map.merge(query, merge)
    query = URI.encode_query(query)
    %URI{uri | query: query}
  end

  @spec uri_to_path(URI.t()) :: URI.t()
  defp uri_to_path(%URI{} = uri) do
    %{uri | authority: nil, host: nil, scheme: nil}
  end

  @impl true
  def handle_params(params, uri, socket) do
    requested_before_key = params["before"]
    requested_after_key = params["after"]

    {:ok, type} = Types.get_type_for_name(params["type"])

    parsed_uri = uri |> URI.parse() |> uri_to_path()

    reference =
      case {params["id"], params["references"]} do
        {nil, nil} ->
          nil

        {id, nil} ->
          {id, ""} = Integer.parse(id)
          {type, id}

        {_, value} ->
          [type, id] = String.split(value, ":", max_parts: 2)
          {:ok, type} = Types.get_type_for_name(type)
          {id, ""} = Integer.parse(id)
          {type, id}
      end

    ids =
      case params["ids"] do
        nil ->
          nil

        value ->
          value
          |> String.split(",")
          |> MapSet.new()
      end

    filter = %Filter{
      ids: ids,
      reference: reference,
      query: params["query"]
    }

    assigns = [
      type: type,
      active: Types.get_name!(type),
      parsed_uri: parsed_uri,
      requested_before_key: requested_before_key,
      requested_after_key: requested_after_key,
      filter: filter,
      last_clicked_id: nil,
      show_selected: false
    ]

    socket =
      socket
      |> assign(assigns)
      |> reload()

    {:noreply, socket}
  end

  @spec get_filter(assigns :: map()) :: map()
  defp get_filter(assigns) do
    case assigns.show_selected do
      false -> assigns.filter
      true -> %Filter{ids: assigns.filter}
    end
  end

  def reload(socket) do
    type = socket.assigns.type
    parsed_uri = socket.assigns.parsed_uri
    requested_before_key = socket.assigns.requested_before_key
    requested_after_key = socket.assigns.requested_after_key
    filter = get_filter(socket.assigns)

    parents =
      case socket.assigns.filter.reference do
        nil ->
          []

        reference ->
          {ref_type, ref_id} = reference

          ref_id
          |> Query.query_parents(ref_type)
          |> Enum.group_by(fn {_icon, position} -> position end)
          |> Enum.map(fn {position, list} ->
            {position, Enum.map(list, fn {icon, _} -> icon end)}
          end)
          |> Enum.sort_by(fn {position, _} -> -position end)
      end

    {icons, before_key, after_key, total_count} =
      Query.get_page_icons(filter, requested_before_key, requested_after_key, 10, "thumb", type)

    before_url =
      case before_key do
        nil ->
          nil

        key ->
          parsed_uri
          |> uri_merge(%{"before" => key}, ["after"])
          |> URI.to_string()
      end

    after_url =
      case after_key do
        nil ->
          nil

        key ->
          parsed_uri
          |> uri_merge(%{"after" => key}, ["before"])
          |> URI.to_string()
      end

    assigns = [
      icons: icons,
      parse_url: parsed_uri,
      before_url: before_url,
      after_url: after_url,
      total_count: total_count,
      parents: parents
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

      state and not current ->
        MapSet.put(mapset, id)

      true ->
        mapset
    end
  end

  defp num_selected(mapset) do
    MapSet.size(mapset)
  end

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

  @impl true
  @spec handle_event(String.t(), any, Phoenix.LiveView.Socket.t()) ::
          {:noreply, Phoenix.LiveView.Socket.t()}
  def handle_event("goto", params, socket) do
    %{"id" => id, "type" => type} = params
    id = to_int(id)
    {:ok, type} = Types.get_type_for_name(type)
    type_name = Types.get_name!(type)
    url = Routes.object_list_path(socket, :index, type_name, id)

    socket =
      cond do
        type == socket.assigns.type -> push_patch(socket, to: url)
        true -> push_redirect(socket, to: url)
      end

    {:noreply, socket}
  end

  @impl true
  def handle_event("search", params, socket) do
    %{"query" => query} = params

    search =
      if query == "" do
        %{}
      else
        %{"query" => query}
      end

    url =
      socket.assigns.parsed_uri
      |> uri_merge(search, ["before", "after", "query"])
      |> URI.to_string()

    socket = push_patch(socket, to: url)
    {:noreply, socket}
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
              socket.assigns.icons,
              socket.assigns.last_clicked_id,
              clicked_id
            )

          {s, socket}

        alt_key ->
          type_name = socket.assigns.type.get_type_name()
          url = Routes.object_list_path(socket, :index, type_name, clicked_id)
          socket = push_patch(socket, to: url)
          {socket.assigns.selected_ids, socket}

        true ->
          {MapSet.new([clicked_id]), socket}
      end

    assigns = [
      selected_ids: selected_ids,
      last_clicked_id: clicked_id
    ]

    {:noreply, assign(socket, assigns)}
  end

  @impl true
  def handle_event("show-selected", _params, socket) do
    {:noreply, socket |> assign(show_selected: true) |> reload()}
  end

  @impl true
  def handle_event("select-none", _params, socket) do
    {:noreply, socket |> assign(show_selected: false, selected_ids: MapSet.new()) |> reload()}
  end

  @impl true
  def handle_event("show-all", _params, socket) do
    {:noreply, socket |> assign(show_selected: false) |> reload()}
  end

  @impl true
  def handle_event("select-object", %{"id" => id}, socket) do
    id = to_int(id)
    socket = assign(socket, selected_ids: MapSet.new([id]), num_selected: 1) |> reload()
    {:noreply, socket}
  end

  @spec icon_classes(Icon.t(), MapSet.t(), integer) :: list(String.t())
  defp icon_classes(%Icon{} = icon, selected_ids, last_clicked_id) do
    result = []

    result =
      cond do
        last_clicked_id == icon.id -> ["last_clicked" | result]
        true -> result
      end

    result =
      cond do
        MapSet.member?(selected_ids, icon.id) -> ["selected" | result]
        true -> result
      end

    result
  end

  @impl true
  def handle_info(%{topic: "refresh"}, socket) do
    socket = reload(socket)
    send_update(PenguinMemoriesWeb.ObjectDetailComponent, id: :detail, status: "refresh")
    {:noreply, socket}
  end

  @spec to_int(String.t()) :: integer
  def to_int(int) do
    {int, ""} = Integer.parse(int)
    int
  end
end
