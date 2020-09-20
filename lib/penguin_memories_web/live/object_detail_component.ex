defmodule PenguinMemoriesWeb.ObjectDetailComponent do
  use PenguinMemoriesWeb, :live_component

  alias PenguinMemories.Repo
  alias PenguinMemories.Objects

  @impl true
  def mount(socket) do
    assigns = [
      edit: false,
      changeset: nil,
    ]

    {:ok, assign(socket, assigns)}
  end

  @impl true
  def update(%{status: "refresh"}, socket) do
    socket = reload(socket)
    {:ok, socket}
  end

  @impl true
  def update(params, socket) do
    type = params.type
    selected_ids = params.selected_ids
    num_selected = MapSet.size(selected_ids)

    assigns = [
      type: type,
      num_selected: num_selected,
      selected_ids: selected_ids,
      edit: false
    ]

    socket = socket
    |> assign(assigns)
    |> reload()

    {:ok, socket}
  end

  def reload(socket) do
    type = socket.assigns.type
    num_selected = socket.assigns.num_selected
    selected_ids = socket.assigns.selected_ids

    {selected_object, selected_fields, icons, more_icons} = cond do
      num_selected == 0 ->
        {nil, nil, [], false}
      num_selected == 1 ->
        [id] = MapSet.to_list(selected_ids)
        case type.get_details(id) do
          nil -> {nil, nil, [], true}
          {object, icon, fields} -> {object, fields, [icon], false}
        end
      true ->
        limit = 5
        icons = type.get_icons(selected_ids, limit)
        fields = type.get_bulk_update_fields()
        {nil, fields, icons, length(icons) >= limit}
    end

    assigns = [
      selected_object: selected_object,
      selected_fields: selected_fields,
      more_icons: more_icons,
      icons: icons,
    ]

    assign(socket, assigns)
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

  @spec output_field(Objects.Field.t(), keyword()) :: any()
  def output_field(field, _opts \\ []) do
    case field.type do
      :markdown ->
        case Earmark.as_html(field.display) do
          {:ok, html_doc, _} -> Phoenix.HTML.raw(html_doc)
          {:error, _, errors} ->
            result = ["</ul>"]
            result = Enum.reduce(errors, result, fn {_, _, text}, acc -> ["<li>", text, "</li>" | acc] end)
            result = ["<ul class='alert alert-danger'>" | result]
            Phoenix.HTML.raw(result)
        end
      _ -> field.display
    end
  end

  @spec input_field(Phoenix.HTML.Form.t(), Objects.Field.t(), keyword()) :: any()
  def input_field(form, field, _opts \\ []) do
    case field.type do
        :markdown -> textarea_input_field(form, field.id, opts)
        _ -> text_input_field(form, field.id, opts)
      end
  end

end
