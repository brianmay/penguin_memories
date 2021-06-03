defmodule PenguinMemoriesWeb.MainLive do
  @moduledoc """
  Live view to display list of objects
  """
  use PenguinMemoriesWeb, :live_view

  alias Elixir.Phoenix.LiveView.Socket
  alias PenguinMemories.Accounts.User
  alias PenguinMemories.Auth
  alias PenguinMemories.Database.Query
  alias PenguinMemories.Database.Types
  alias PenguinMemories.Photos
  alias PenguinMemories.Urls
  alias PenguinMemoriesWeb.ObjectListLive
  alias PenguinMemoriesWeb.Router.Helpers, as: Routes

  @impl true
  @spec mount(map(), map(), Socket.t()) :: {:ok, Socket.t()}
  def mount(_params, session, socket) do
    assigns =
      case Auth.load_user(session) do
        {:ok, %User{} = user} ->
          [user: user]

        :not_logged_in ->
          [user: nil]
      end

    socket = assign(socket, assigns)

    socket =
      assign(socket, reference_pid: nil, objects_pid: nil, photos_pid: nil, details_pid: nil)

    PenguinMemoriesWeb.Endpoint.subscribe("refresh")
    {:ok, socket}
  end

  @impl true
  def handle_params(params, uri, socket) do
    {:ok, type} = Types.get_type_for_name(params["type"])

    url = Urls.parse_url(uri)

    reference_type_id =
      case {params["id"], params["reference"]} do
        {nil, nil} ->
          nil

        {id, nil} ->
          {id, ""} = Integer.parse(id)
          {type, id}

        {_, value} ->
          [type, id] = String.split(value, "/", max_parts: 2)
          {:ok, type} = Types.get_type_for_name(type)
          {id, ""} = Integer.parse(id)
          {type, id}
      end

    big_value = params["big"]

    obj_filter = %Query.Filter{
      reference_type_id: reference_type_id,
      query: params["query"]
    }

    objects = %ObjectListLive.Request{
      type: type,
      filter: obj_filter,
      before_name: "obj_before",
      before_key: params["obj_before"],
      after_name: "obj_after",
      after_key: params["obj_after"],
      show_selected_name: "obj_show_selected",
      show_selected_value: Map.has_key?(params, "obj_show_selected"),
      selected_name: "obj_selected",
      selected_value: parse_selected(params["obj_selected"]),
      drop_on_select: ["p_selected"],
      big_value: big_value
    }

    num_selected = MapSet.size(objects.selected_value)

    photo_filter =
      cond do
        num_selected == 0 and is_nil(reference_type_id) ->
          %Query.Filter{ids: MapSet.new()}

        num_selected == 1 ->
          [selected] = MapSet.to_list(objects.selected_value)

          %Query.Filter{
            reference_type_id: {objects.type, selected}
          }

        true ->
          %Query.Filter{
            reference_type_id: reference_type_id
          }
      end

    photos = %ObjectListLive.Request{
      type: Photos.Photo,
      filter: photo_filter,
      before_name: "p_before",
      before_key: params["p_before"],
      after_name: "p_after",
      after_key: params["p_after"],
      show_selected_name: "p_show_selected",
      show_selected_value: Map.has_key?(params, "p_show_selected"),
      selected_name: "p_selected",
      selected_value: parse_selected(params["p_selected"]),
      big_value: big_value
    }

    assigns = [
      query: params["query"],
      reference_type_id: reference_type_id,
      active: Types.get_name!(type),
      url: url,
      objects: objects,
      photos: photos,
      big_value: big_value
    ]

    socket = assign(socket, assigns)
    reload(socket)

    {:noreply, socket}
  end

  @impl true
  def handle_event("search", params, socket) do
    search =
      case params do
        %{"query" => ""} -> %{}
        %{"query" => q} -> %{"query" => q}
      end

    type = Types.get_name!(socket.assigns.objects.type)
    url = Routes.main_path(socket, :index, type, search)

    socket = push_patch(socket, to: url)
    {:noreply, socket}
  end

  @impl true
  def handle_info({:child_pid, "details", pid}, socket) do
    socket = assign(socket, details_pid: pid)
    :ok = notify_details(socket)
    {:noreply, socket}
  end

  @impl true
  def handle_info({:child_pid, "reference", pid}, socket) do
    socket = assign(socket, reference_pid: pid)
    :ok = notify_reference(socket)
    {:noreply, socket}
  end

  @impl true
  def handle_info({:child_pid, "objects", pid}, socket) do
    socket = assign(socket, objects_pid: pid)
    :ok = notify_objects(socket)
    {:noreply, socket}
  end

  @impl true
  def handle_info({:child_pid, "photos", pid}, socket) do
    socket = assign(socket, photos_pid: pid)
    :ok = notify_photos(socket)
    {:noreply, socket}
  end

  @impl true
  def handle_info(%{topic: "refresh"}, socket) do
    :ok = reload(socket)
    {:noreply, socket}
  end

  @spec reload(Socket.t()) :: :ok
  defp reload(socket) do
    :ok = notify_details(socket)
    :ok = notify_reference(socket)
    :ok = notify_objects(socket)
    :ok = notify_photos(socket)
    :ok
  end

  @spec notify_details(Socket.t()) :: :ok
  defp notify_details(socket) do
    if socket.assigns.details_pid != nil do
      pid = socket.assigns.details_pid
      type = socket.assigns.objects.type
      send(pid, {:parameters, type})
    end

    :ok
  end

  @spec notify_reference(Socket.t()) :: :ok
  defp notify_reference(socket) do
    if socket.assigns.reference_pid != nil and socket.assigns.reference_type_id != nil do
      pid = socket.assigns.reference_pid
      {type, id} = socket.assigns.reference_type_id

      send(
        pid,
        {:parameters, type, id, socket.assigns.url, socket.host_uri, nil, nil,
         socket.assigns.big_value}
      )
    end

    :ok
  end

  @spec notify_objects(Socket.t()) :: :ok
  defp notify_objects(socket) do
    if socket.assigns.objects_pid != nil do
      pid = socket.assigns.objects_pid
      send(pid, {:parameters, socket.assigns.objects, socket.assigns.url, socket.host_uri})
    end

    :ok
  end

  @spec notify_photos(Socket.t()) :: :ok
  defp notify_photos(socket) do
    if socket.assigns.photos_pid != nil do
      photos = socket.assigns.photos
      pid = socket.assigns.photos_pid
      send(pid, {:parameters, photos, socket.assigns.url, socket.host_uri})
    end

    :ok
  end

  @spec parse_selected(String.t() | nil) :: ObjectListLive.selected_type()
  defp parse_selected(nil), do: MapSet.new()
  defp parse_selected("all"), do: :all

  defp parse_selected(list) do
    list
    |> String.split(",")
    |> Enum.map(fn v -> to_int(v) end)
    |> MapSet.new()
  end

  @spec to_int(String.t()) :: integer
  defp to_int(int) do
    case Integer.parse(int) do
      {value, ""} -> value
      _ -> 0
    end
  end
end
