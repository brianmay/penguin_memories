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
  alias PenguinMemories.Loaders
  alias PenguinMemories.Photos
  alias PenguinMemories.Urls

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

    filter = %Query.Filter{
      reference_type_id: reference_type_id,
      query: params["query"]
    }

    big_value = nil

    objects = %Loaders.ListRequest{
      type: type,
      filter: filter,
      before_name: "obj_before",
      before_key: params["obj_before"],
      after_name: "obj_after",
      after_key: params["obj_after"],
      show_selected_name: "obj_show_selected",
      show_selected_value: Map.has_key?(params, "obj_show_selected"),
      big_value: big_value
    }

    photos = %Loaders.ListRequest{
      type: Photos.Photo,
      filter: filter,
      before_name: "p_before",
      before_key: params["p_before"],
      after_name: "p_after",
      after_key: params["p_after"],
      show_selected_name: "p_show_selected",
      show_selected_value: Map.has_key?(params, "p_show_selected"),
      big_value: big_value
    }

    assigns = [
      # type: type,
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

    url =
      socket.assigns.url
      |> Urls.url_merge(search, ["obj_before", "obj_after", "p_before", "p_after", "query"])
      |> URI.to_string()

    socket = push_patch(socket, to: url)
    {:noreply, socket}
  end

  @impl true
  def handle_info({:big, big_value}, %Socket{} = socket) do
    objects = %Loaders.ListRequest{socket.assigns.objects | big_value: big_value}
    photos = %Loaders.ListRequest{socket.assigns.photos | big_value: big_value}
    socket = assign(socket, objects: objects, photos: photos, big_value: big_value)
    :ok = reload(socket)
    {:noreply, socket}
  end

  @impl true
  def handle_info({:child_pid, "details", pid}, socket) do
    type = socket.assigns.objects.type
    send(pid, {:parameters, type})
    {:noreply, assign(socket, details_pid: pid)}
  end

  @impl true
  def handle_info({:child_pid, "reference", pid}, socket) do
    {type, id} = socket.assigns.reference_type_id
    send(pid, {:parameters, type, id, socket.assigns.url, socket.host_uri, nil, nil, socket.assigns.big_value})
    {:noreply, assign(socket, reference_pid: pid)}
  end

  @impl true
  def handle_info({:child_pid, "objects", pid}, socket) do
    send(pid, {:parameters, socket.assigns.objects, socket.assigns.url, socket.host_uri})
    {:noreply, assign(socket, objects_pid: pid)}
  end

  @impl true
  def handle_info({:child_pid, "photos", pid}, socket) do
    send(pid, {:parameters, socket.assigns.photos, socket.assigns.url, socket.host_uri})
    {:noreply, assign(socket, photos_pid: pid)}
  end

  @impl true
  def handle_info(%{topic: "refresh"}, socket) do
    :ok = reload(socket)
    {:noreply, socket}
  end

  @spec reload(Socket.t()) :: :ok
  defp reload(socket) do
    if socket.assigns.details_pid != nil do
      pid = socket.assigns.details_pid
      type = socket.assigns.objects.type
      send(pid, {:parameters, type})
    end

    if socket.assigns.reference_pid != nil do
      pid = socket.assigns.reference_pid
      {type, id} = socket.assigns.reference_type_id
      send(pid, {:parameters, type, id, socket.assigns.url, socket.host_uri, nil, nil, socket.assigns.big_value})
    end

    if socket.assigns.objects_pid != nil do
      pid = socket.assigns.objects_pid
      send(pid, {:parameters, socket.assigns.objects, socket.assigns.url, socket.host_uri})
    end

    if socket.assigns.photos_pid != nil do
      pid = socket.assigns.photos_pid
      send(pid, {:parameters, socket.assigns.photos, socket.assigns.url, socket.host_uri})
    end

    :ok
  end
end
