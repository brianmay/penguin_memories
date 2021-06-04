defmodule PenguinMemoriesWeb.ObjectListLive do
  @moduledoc """
  Live view to display list of objects
  """
  use PenguinMemoriesWeb, :live_view

  alias Elixir.Phoenix.LiveView.Socket

  alias PenguinMemories.Database
  alias PenguinMemories.Database.Query
  alias PenguinMemories.Database.Types
  alias PenguinMemories.Urls
  alias PenguinMemoriesWeb.LiveRequest

  @type selected_type :: MapSet.t() | :all

  defmodule Request do
    @moduledoc """
    List of icons to display
    """
    @type selected_type :: PenguinMemoriesWeb.ObjectListLive.selected_type()

    @type t :: %__MODULE__{
            type: Database.object_type(),
            filter: Query.Filter.t(),
            before_name: String.t(),
            before_key: String.t(),
            after_name: String.t(),
            after_key: String.t(),
            show_selected_name: String.t(),
            show_selected_value: boolean(),
            selected_name: String.t(),
            selected_value: selected_type,
            drop_on_select: list(String.t())
          }
    @enforce_keys [
      :type,
      :filter,
      :before_name,
      :before_key,
      :after_name,
      :after_key,
      :show_selected_name,
      :show_selected_value,
      :selected_name,
      :selected_value
    ]
    defstruct type: nil,
              filter: %Query.Filter{},
              before_name: nil,
              before_key: nil,
              after_name: nil,
              after_key: nil,
              show_selected_name: nil,
              show_selected_value: false,
              selected_name: nil,
              selected_value: MapSet.new(),
              drop_on_select: []
  end

  defmodule Response do
    @moduledoc """
    List of icons to display
    """
    @type t :: %__MODULE__{
            before_key: String.t(),
            before_url: String.t(),
            after_key: String.t(),
            after_url: String.t(),
            icons: list(Query.Icon.t()),
            count: integer()
          }
    @enforce_keys [:before_key, :before_url, :after_key, :after_url, :icons, :count]
    defstruct before_key: nil,
              before_url: nil,
              after_key: nil,
              after_url: nil,
              icons: [],
              count: 0
  end

  @impl true
  @spec mount(map(), map(), Socket.t()) :: {:ok, Socket.t()}
  def mount(_params, _session, socket) do
    assigns = [
      request: nil,
      url: nil,
      last_clicked_id: nil,
      response: nil,
      selected_pid: nil,
      update_pid: nil,
      common: %LiveRequest{
        url: nil,
        host_url: nil,
        user: nil,
        big_id: nil,
        force_reload: nil
      }
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
          s = toggle(socket.assigns.request.selected_value, clicked_id)
          {s, socket}

        shift_key ->
          s =
            toggle_range(
              socket.assigns.request.selected_value,
              socket.assigns.response.icons,
              socket.assigns.last_clicked_id,
              clicked_id
            )

          {s, socket}

        alt_key ->
          type_name = Types.get_name!(socket.assigns.request.type)
          url = Routes.main_path(socket, :index, type_name, clicked_id)
          socket = push_patch(socket, to: url)
          {socket.assigns.request.selected_value, socket}

        true ->
          {MapSet.new([clicked_id]), socket}
      end

    socket =
      socket
      |> assign(last_clicked_id: clicked_id)
      |> set_selected(selected_ids)

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
    socket = set_selected(socket, MapSet.new())
    {:noreply, socket}
  end

  @impl true
  def handle_event("select-all", _params, socket) do
    socket = set_selected(socket, :all)
    {:noreply, socket}
  end

  def handle_info({:parameters, %LiveRequest{} = common, %Request{} = request}, socket) do
    request_changed = socket.assigns.request != request

    socket =
      LiveRequest.apply_common(socket, common)
      |> assign(request: request)

    socket =
      if request_changed or common.force_reload do
        reload(socket)
      else
        # We have to notify the child, because the big value may have changed
        :ok = notify_selected_child(socket)
        :ok = notify_update_child(socket)
        socket
      end

    {:noreply, socket}
  end

  @impl true
  def handle_info({:select_object, id}, socket) do
    socket = set_selected(socket, MapSet.new([id]))
    {:noreply, socket}
  end

  @impl true
  def handle_info({:child_pid, id, pid}, %Socket{} = socket) do
    cond do
      id == child_id(socket, "selected") -> handle_child("selected", pid, socket)
      id == child_id(socket, "update") -> handle_child("update", pid, socket)
    end
  end

  @spec child_id(socket :: Socket.t(), id :: String.t()) :: String.t()
  def child_id(%Socket{} = socket, id) do
    socket.id <> "_" <> id
  end

  @spec handle_child(id :: String.t(), pid :: pid(), socket :: Socket.t()) ::
          {:noreply, Socket.t()}
  def handle_child("selected", pid, %Socket{} = socket) do
    socket = assign(socket, selected_pid: pid)
    :ok = notify_selected_child(socket)
    {:noreply, socket}
  end

  def handle_child("update", pid, %Socket{} = socket) do
    socket = assign(socket, update_pid: pid)
    :ok = notify_update_child(socket)
    {:noreply, socket}
  end

  @spec notify_update_child(Socket.t()) :: :ok
  defp notify_update_child(%Socket{} = socket) do
    if socket.assigns.update_pid != nil do
      request = socket.assigns.request
      type = request.type
      filter = get_update_filter(socket.assigns)
      pid = socket.assigns.update_pid

      new_request = %PenguinMemoriesWeb.ObjectUpdateLive.Request{
        type: type,
        filter: filter
      }

      send(pid, {:parameters, socket.assigns.common, new_request})
    end

    :ok
  end

  @spec notify_selected_child(Socket.t()) :: :ok
  defp notify_selected_child(%Socket{} = socket) do
    if socket.assigns.selected_pid != nil do
      case get_single_selection(socket.assigns.request.selected_value) do
        nil ->
          :ok

        selection_id ->
          request = socket.assigns.request
          type = request.type
          filter = get_filter(socket.assigns)

          pid = socket.assigns.selected_pid

          new_request = %PenguinMemoriesWeb.ObjectDetailsLive.Request{
            type: type,
            id: selection_id
          }

          send(
            pid,
            {:parameters, filter, socket.assigns.common, new_request}
          )
      end
    end

    :ok
  end

  @spec count_selections(selected_ids :: selected_type) :: integer() | :infinity
  def count_selections(:all), do: :infinity
  def count_selections(selected_ids), do: MapSet.size(selected_ids)

  @spec get_single_selection(selected_ids :: selected_type) :: integer() | nil
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

    common = socket.assigns.common
    request = get_request(socket.assigns)
    response = load_objects(request, common.url)
    assign(socket, response: response)
  end

  @spec icon_classes(Query.Icon.t(), selected_type, integer) :: list(String.t())
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

  @spec toggle(selected_ids :: selected_type, id :: integer()) :: selected_type
  defp toggle(selected_ids, id) do
    cond do
      selected_ids == :all ->
        MapSet.new([id])

      MapSet.member?(selected_ids, id) ->
        MapSet.delete(selected_ids, id)

      true ->
        MapSet.put(selected_ids, id)
    end
  end

  @spec set(selected_ids :: selected_type, id :: integer(), state :: boolean()) :: selected_type
  defp set(:all, id, state) do
    cond do
      not state -> MapSet.new([id])
      state -> MapSet.new([id])
    end
  end

  defp set(selected_ids, id, state) do
    current = MapSet.member?(selected_ids, id)

    cond do
      not state and current ->
        MapSet.delete(selected_ids, id)

      state and not current ->
        MapSet.put(selected_ids, id)

      true ->
        selected_ids
    end
  end

  @spec get_update_filter(assigns :: map()) :: map()
  defp get_update_filter(assigns) do
    case assigns.request.selected_value do
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

  @spec get_request(assigns :: map()) :: Request.t()
  def get_request(assigns) do
    filter = get_filter(assigns)
    %Request{assigns.request | filter: filter}
  end

  @spec toggle_range(
          selected_ids :: selected_type,
          icons :: Query.Icon.t(),
          last_clicked_id :: integer(),
          clicked_id :: integer
        ) :: selected_type
  defp toggle_range(:all, _, _, _), do: :all

  # credo:disable-for-next-line Credo.Check.Refactor.CyclomaticComplexity
  defp toggle_range(selected_ids, icons, last_clicked_id, clicked_id) do
    new_state = MapSet.member?(selected_ids, last_clicked_id)

    {state, new_mapset} =
      Enum.reduce(icons, {0, selected_ids}, fn
        icon, {0, selected_ids} ->
          cond do
            icon.id == last_clicked_id ->
              {1, set(selected_ids, icon.id, new_state)}

            icon.id == clicked_id ->
              {1, set(selected_ids, icon.id, new_state)}

            true ->
              {0, selected_ids}
          end

        icon, {1, selected_ids} ->
          cond do
            icon.id == last_clicked_id ->
              {2, set(selected_ids, icon.id, new_state)}

            icon.id == clicked_id ->
              {2, set(selected_ids, icon.id, new_state)}

            true ->
              {1, set(selected_ids, icon.id, new_state)}
          end

        _, {2, selected_ids} ->
          {2, selected_ids}
      end)

    case state do
      0 -> selected_ids
      1 -> selected_ids
      2 -> new_mapset
    end
  end

  @spec to_int(String.t()) :: integer
  defp to_int(int) do
    {int, ""} = Integer.parse(int)
    int
  end

  @spec create_before_after_url(
          uri :: URI.t(),
          this_name :: String.t(),
          other_name :: String.t(),
          key :: String.t() | nil
        ) :: String.t() | nil
  defp create_before_after_url(_uri, _this_name, _other_name, nil), do: nil

  defp create_before_after_url(%URI{} = url, this_name, other_name, key) do
    url
    |> Urls.url_merge(%{this_name => key}, [other_name])
    |> URI.to_string()
  end

  @spec load_objects(request :: Request.t(), url :: URI.t()) :: Response.t()
  defp load_objects(%Request{} = request, %URI{} = url) do
    {icons, before_key, after_key, count} =
      Query.get_page_icons(
        request.filter,
        request.before_key,
        request.after_key,
        20,
        "thumb",
        request.type
      )

    before_url = create_before_after_url(url, request.before_name, request.after_name, before_key)
    after_url = create_before_after_url(url, request.after_name, request.before_name, after_key)

    %Response{
      before_key: before_key,
      before_url: before_url,
      after_key: after_key,
      after_url: after_url,
      icons: icons,
      count: count
    }
  end

  @spec set_selected(socket :: Socket.t(), selected :: selected_type) :: Socket.t()
  defp set_selected(%Socket{} = socket, selected) do
    string =
      cond do
        selected == :all -> "all"
        MapSet.size(selected) == 0 -> nil
        true -> selected |> MapSet.to_list() |> Enum.join(",")
      end

    request = socket.assigns.request

    {add, drop} =
      case string do
        nil -> {%{}, [request.selected_name]}
        string -> {%{request.selected_name => string}, []}
      end

    drop = request.drop_on_select ++ drop

    url =
      socket.assigns.common.url
      |> Urls.url_merge(add, drop)
      |> URI.to_string()

    push_patch(socket, to: url)
  end
end
