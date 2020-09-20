defmodule PenguinMemoriesWeb.ObjectDetailComponent do
  use PenguinMemoriesWeb, :live_component

  alias PenguinMemories.Repo

  @impl true
  def mount(socket) do
    assigns = [
      edit: false,
      changeset: nil,
    ]

    {:ok, assign(socket, assigns)}
  end

  @impl true
  def update(params, socket) do
    type = params.type
    num_selected = MapSet.size(params.selected_ids)

    {selected_object, selected_fields, icons, more_icons} = cond do
      num_selected == 0 ->
        {nil, nil, [], false}
      num_selected == 1 ->
        [id] = MapSet.to_list(params.selected_ids)
        case type.get_details(id) do
          nil -> {nil, nil, [], true}
          {object, icon, fields} -> {object, fields, [icon], false}
        end
      true ->
        limit = 5
        icons = type.get_icons(params.selected_ids, limit)
        fields = type.get_bulk_update_fields()
        {nil, fields, icons, length(icons) >= limit}
    end

    assigns = [
      num_selected: num_selected,
      selected_object: selected_object,
      selected_fields: selected_fields,
      selected_ids: params.selected_ids,
      more_icons: more_icons,
      icons: icons,
      type: type,
      edit: false
    ]
    socket = socket
    |> assign(assigns)
    {:ok, socket}
  end

  @impl true
  def handle_event("edit", _params, socket) do
    type = socket.assigns.type
    changeset = type.changeset(socket.assigns.selected_object, %{})
    changeset = %{changeset | action: :update}
    assigns = [
      edit: true,
      changeset: changeset
    ]
    {:noreply, assign(socket, assigns)}
  end

  @impl true
  def handle_event("save", _params, socket) do
    {edit, changeset} = case Repo.update(socket.assigns.changeset) do
                          {:error, changeset} ->     
                            {true, changeset}
                          {:ok, _} ->
                            PenguinMemoriesWeb.Endpoint.broadcast("refresh", "refresh", %{})
                            {false, nil}
                        end
    changeset = %{changeset | action: :update}
    assigns = [
      edit: edit,
      changeset: changeset
    ]
    {:noreply, assign(socket, assigns)}
  end

  @impl true
  def handle_event("cancel", _params, socket) do
    assigns = [
      edit: false,
      changeset: nil
    ]
    {:noreply, assign(socket, assigns)}
  end

  @impl true
  def handle_event("validate", %{"object" => params}, socket) do
    type = socket.assigns.type

    changeset = type.changeset(socket.assigns.selected_object, params)
    changeset = %{changeset | action: :update}

    assigns = [
      changeset: changeset
    ]
    {:noreply, assign(socket, assigns)}
  end

end
