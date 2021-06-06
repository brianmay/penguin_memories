defmodule PenguinMemoriesWeb.MainLive do
  @moduledoc """
  Live view to display list of objects
  """
  use PenguinMemoriesWeb, :live_view

  alias Elixir.Phoenix.LiveView.Socket
  alias PenguinMemories.Database
  alias PenguinMemories.Database.Query
  alias PenguinMemories.Database.Types
  alias PenguinMemories.Photos
  alias PenguinMemories.Urls
  alias PenguinMemoriesWeb.ObjectListLive
  alias PenguinMemoriesWeb.Router.Helpers, as: Routes

  @type selected_type :: MapSet.t() | :all

  @impl true
  @spec mount(map(), map(), Socket.t()) :: {:ok, Socket.t()}
  def mount(_params, session, socket) do
    socket = assign_defaults(socket, session)

    socket =
      assign(socket, reference_pid: nil, objects_pid: nil, photos_pid: nil, details_pid: nil)

    PenguinMemoriesWeb.Endpoint.subscribe("refresh")
    {:ok, socket}
  end

  @impl true
  def handle_params(params, uri, socket) do
    {:ok, type} = Types.get_type_for_name(params["type"])

    url = Urls.parse_url(uri)

    reference_type_id = parse_reference_type_id(params["id"], params["reference"], type)

    big_id = params["big"]

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
      drop_on_select: ["p_selected"]
    }

    num_selected = count_selections(objects.selected_value)

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
      selected_value: parse_selected(params["p_selected"])
    }

    page_title =
      case reference_type_id do
        nil ->
          name = Query.get_plural_name(type) |> String.capitalize()
          "#{name} · Penguin Memories"

        {ref_type, ref_id} ->
          ref_name = Query.get_single_name(ref_type) |> String.capitalize()
          "#{ref_name} #{ref_id} · Penguin Memories"
      end

    assigns = [
      page_title: page_title,
      query: params["query"],
      reference_type_id: reference_type_id,
      active: Types.get_name!(type),
      url: url,
      objects: objects,
      photos: photos,
      big_id: big_id
    ]

    socket = assign(socket, assigns)
    reload(socket)

    {:noreply, socket}
  end

  @impl true
  def handle_event("search", params, %Socket{} = socket) do
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
  def handle_info({:select_object, id}, socket) do
    type = socket.assigns.objects.type
    type_name = Types.get_name!(type)

    {ref_type, _} = socket.assigns.reference_type_id
    ref_type_name = Types.get_name!(ref_type)

    url =
      socket.assigns.url
      |> Urls.set_path(Routes.main_path(socket, :index, type_name))
      |> Urls.url_merge(%{"reference" => "#{ref_type_name}/#{id}"}, ["obj_selected", "p_selected"])
      |> URI.to_string()

    socket = push_patch(socket, to: url)
    {:noreply, socket}
  end

  @impl true
  def handle_info({:child_pid, "details", pid}, %Socket{} = socket) do
    socket = assign(socket, details_pid: pid)
    :ok = notify_details(socket, false)
    {:noreply, socket}
  end

  @impl true
  def handle_info({:child_pid, "reference", pid}, %Socket{} = socket) do
    socket = assign(socket, reference_pid: pid)
    :ok = notify_reference(socket, false)
    {:noreply, socket}
  end

  @impl true
  def handle_info({:child_pid, "objects", pid}, %Socket{} = socket) do
    socket = assign(socket, objects_pid: pid)
    :ok = notify_objects(socket, false)
    {:noreply, socket}
  end

  @impl true
  def handle_info({:child_pid, "photos", pid}, %Socket{} = socket) do
    socket = assign(socket, photos_pid: pid)
    :ok = notify_photos(socket, false)
    {:noreply, socket}
  end

  @impl true
  def handle_info({:title, "reference", title}, socket) do
    page_title = "#{title} · Penguin Memories"
    socket = assign(socket, page_title: page_title)
    {:noreply, socket}
  end

  def handle_info({:title, _id, _title}, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_info(%{topic: "refresh"}, %Socket{} = socket) do
    :ok = force_reload(socket)
    {:noreply, socket}
  end

  @spec get_common(Socket.t(), force_reload :: boolean()) :: PenguinMemoriesWeb.LiveRequest.t()
  def get_common(%Socket{} = socket, force_reload) do
    %PenguinMemoriesWeb.LiveRequest{
      url: socket.assigns.url,
      host_url: socket.host_uri,
      user: socket.assigns.user,
      big_id: socket.assigns.big_id,
      force_reload: force_reload
    }
  end

  @spec reload(Socket.t()) :: :ok
  defp reload(%Socket{} = socket) do
    :ok = notify_details(socket, false)
    :ok = notify_reference(socket, false)
    :ok = notify_objects(socket, false)
    :ok = notify_photos(socket, false)
    :ok
  end

  @spec force_reload(Socket.t()) :: :ok
  defp force_reload(%Socket{} = socket) do
    :ok = notify_details(socket, true)
    :ok = notify_reference(socket, true)
    :ok = notify_objects(socket, true)
    :ok = notify_photos(socket, true)
    :ok
  end

  @spec notify_details(Socket.t(), force_reload :: boolean) :: :ok
  defp notify_details(%Socket{} = socket, force_reload) do
    if socket.assigns.details_pid != nil do
      common = get_common(socket, force_reload)
      pid = socket.assigns.details_pid

      request = %PenguinMemoriesWeb.ListDetailsLive.Request{
        type: socket.assigns.objects.type
      }

      send(pid, {:parameters, common, request})
    end

    :ok
  end

  @spec notify_reference(Socket.t(), force_reload :: boolean) :: :ok
  defp notify_reference(%Socket{} = socket, force_reload) do
    if socket.assigns.reference_pid != nil and socket.assigns.reference_type_id != nil do
      common = get_common(socket, force_reload)
      pid = socket.assigns.reference_pid
      {type, id} = socket.assigns.reference_type_id

      filter = %Query.Filter{}

      request = %PenguinMemoriesWeb.ObjectDetailsLive.Request{
        type: type,
        id: id
      }

      send(
        pid,
        {:parameters, filter, common, request}
      )
    end

    :ok
  end

  @spec notify_objects(Socket.t(), force_reload :: boolean) :: :ok
  defp notify_objects(%Socket{} = socket, force_reload) do
    if socket.assigns.objects_pid != nil do
      common = get_common(socket, force_reload)
      pid = socket.assigns.objects_pid
      send(pid, {:parameters, common, socket.assigns.objects})
    end

    :ok
  end

  @spec notify_photos(Socket.t(), force_reload :: boolean) :: :ok
  defp notify_photos(%Socket{} = socket, force_reload) do
    if socket.assigns.photos_pid != nil do
      common = get_common(socket, force_reload)
      photos = socket.assigns.photos
      pid = socket.assigns.photos_pid
      send(pid, {:parameters, common, photos})
    end

    :ok
  end

  @spec parse_reference_type_id(
          id :: String.t() | nil,
          reference :: String.t() | nil,
          type :: Database.object_type()
        ) :: {Database.object_type(), integer()} | nil
  defp parse_reference_type_id(id, reference, default_type) do
    case {id, reference} do
      {nil, nil} ->
        nil

      {id, nil} ->
        case Integer.parse(id) do
          {id, ""} -> {default_type, id}
          _ -> nil
        end

      {_, value} ->
        with [type_name, id] <- String.split(value, "/", max_parts: 2),
             {:ok, type} <- Types.get_type_for_name(type_name),
             {id, ""} <- Integer.parse(id) do
          {type, id}
        else
          _ -> nil
        end
    end
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

  @spec count_selections(selected_ids :: selected_type) :: integer() | :infinity
  def count_selections(:all), do: :infinity
  def count_selections(selected_ids), do: MapSet.size(selected_ids)
end
