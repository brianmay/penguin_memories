defmodule PenguinMemoriesWeb.ObjectDetailComponent do
  @moduledoc """
  Live component to display/edit details of a component.
  """
  use PenguinMemoriesWeb, :live_component

  alias Ecto.Changeset
  alias Phoenix.LiveView.Socket
  alias PenguinMemories.Objects
  alias PenguinMemories.Auth

  @impl true
  def mount(socket) do
    assigns = [
      edit: nil,
      edit_object: nil,
      enabled: nil,
      action: nil,
      changeset: nil,
      error: nil,
      selected_object: nil,
      user: nil
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
      error: nil,
      edit: nil,
      edit_object: nil,
      enabled: nil,
      action: nil,
      user: params.user
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
          nil -> {nil, nil, [], false}
          {object, icon, fields} -> {object, fields, [icon], false}
        end
      true ->
        limit = 5
        icons = type.get_icons(selected_ids, limit)
        fields = type.get_update_fields()
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
  def handle_event("create", _params, socket) do
    if Auth.can_edit(socket.assigns.user) do
      handle_create(socket)
    else
      {:noreply, assign(socket, :error, "Permission denied")}
    end
  end

  @impl true
  def handle_event("edit", _params, socket) do
    if Auth.can_edit(socket.assigns.user) do
      handle_edit(socket)
    else
      {:noreply, assign(socket, :error, "Permission denied")}
    end
  end

  @impl true
  def handle_event("update", _params, socket) do
    if Auth.can_edit(socket.assigns.user) do
      handle_update(socket)
    else
      {:noreply, assign(socket, :error, "Permission denied")}
    end
  end

  @impl true
  def handle_event("delete", _params, socket) do
    if Auth.can_edit(socket.assigns.user) do
      handle_delete(socket)
    else
      {:noreply, assign(socket, :error, "Permission denied")}
    end
  end

  @impl true
  def handle_event("validate", %{"object" => params}, socket) do
    if Auth.can_edit(socket.assigns.user) do
      handle_validate(socket, params)
    else
      {:noreply, assign(socket, :error, "Permission denied")}
    end
  end

  @impl true
  def handle_event("save", %{"object" => params}, socket) do
    if Auth.can_edit(socket.assigns.user) do
      handle_save(socket, params)
    else
      {:noreply, assign(socket, :error, "Permission denied")}
    end
  end

  @impl true
  def handle_event("cancel", _params, socket) do
    assigns = [
      edit: nil,
      changeset: nil,
      error: nil,
      enabled: nil
    ]
    {:noreply, assign(socket, assigns)}
  end

  @spec handle_create(Socket.t()) :: {:noreply, Socket.t()}
  defp handle_create(socket) do
    type = socket.assigns.type
    changeset = type.get_create_child_changeset(socket.assigns.selected_object, %{})
    assigns = [
      edit: :edit,
      changeset: changeset,
      edit_object: changeset.data,
      action: :insert
    ]
    {:noreply, assign(socket, assigns)}
  end

  @spec handle_edit(Socket.t()) :: {:noreply, Socket.t()}
  defp handle_edit(socket) do
    type = socket.assigns.type
    changeset = type.get_edit_changeset(socket.assigns.selected_object, %{})
    changeset = %{changeset | action: :update}
    assigns = [
      edit: :edit,
      changeset: changeset,
      edit_object: changeset.data,
      action: :update
    ]
    {:noreply, assign(socket, assigns)}
  end

  @spec handle_update(Socket.t()) :: {:noreply, Socket.t()}
  defp handle_update(socket) do
    type = socket.assigns.type
    enabled = MapSet.new()
    changeset = type.get_update_changeset(enabled, %{})
    changeset = %{changeset | action: :update}
    assigns = [
      edit: :update,
      changeset: changeset,
      edit_object: changeset.data,
      enabled: enabled,
      action: :update
    ]
    {:noreply, assign(socket, assigns)}
  end

  @spec handle_delete(Socket.t()) :: {:noreply, Socket.t()}
  defp handle_delete(socket) do
    type = socket.assigns.type
    {socket, assigns} = case type.delete(socket.assigns.selected_object) do
                          {:error, error} ->
                            assigns = [
                              error: error
                            ]
                            {socket, assigns}
                          :ok ->
                            PenguinMemoriesWeb.Endpoint.broadcast("refresh", "refresh", %{})
                            type_name = socket.assigns.type.get_type_name()
                            url = Routes.object_list_path(socket, :index, type_name)
                            socket = push_patch(socket, to: url)
                            assigns = [
                              error: nil
                            ]
                            {socket, assigns}
                      end
    {:noreply, assign(socket, assigns)}
  end

  @spec string_to_boolean(String.t()) :: boolean
  defp string_to_boolean("true"), do: true
  defp string_to_boolean(_), do: false

  # ---- EDIT -----
  @spec get_edit_changeset(Socket.t(), map()) :: Changeset.t()
  defp get_edit_changeset(socket, params) do
    type = socket.assigns.type

    changeset = type.get_edit_changeset(socket.assigns.edit_object, params)
    changeset = %{changeset | action: socket.assigns.action}

    changeset
  end

  # ---- UPDATE -----
  @spec get_update_changes(list(Objects.Field.t()), map()) :: {MapSet.t(), map()}
  def get_update_changes(fields, params) do
    Enum.reduce(fields, {MapSet.new(), %{}}, fn
      field, {enabled, changes} ->
        field_id = Atom.to_string(field.id)
      enable_id = Atom.to_string(field_to_enable_field_id(field))
      enable_value = string_to_boolean(Map.get(params, enable_id, "false"))
      if enable_value do
        enabled = MapSet.put(enabled, field.id)
        changes = Map.put(changes, field.id, Map.get(params, field_id))
        {enabled, changes}
      else
        {enabled, changes}
      end
    end)
  end

  @spec get_update_changeset(Socket.t(), map()) :: {MapSet.t(), Changeset.t()}
  defp get_update_changeset(socket, params) do
    type = socket.assigns.type

    {enabled, changes} = get_update_changes(socket.assigns.selected_fields, params)
    changeset = type.get_update_changeset(enabled, changes)
    changeset = %{changeset | action: socket.assigns.action}

    {enabled, changeset}
  end

  # ---- VALIDATE -----
  @spec handle_validate(Socket.t(), map()) :: {:noreply, Socket.t()}
  def handle_validate(socket, params) do
    case socket.assigns.edit do
      :edit -> handle_edit_validate(socket, params)
      :update -> handle_update_validate(socket, params)
    end
  end

  @spec handle_edit_validate(Socket.t(), map()) :: {:noreply, Socket.t()}
  def handle_edit_validate(socket, params) do
    changeset = get_edit_changeset(socket, params)
    assigns = [
      changeset: changeset
    ]
    {:noreply, assign(socket, assigns)}
  end

  @spec handle_update_validate(Socket.t(), map()) :: {:noreply, Socket.t()}
  def handle_update_validate(socket, params) do
    {enabled, changeset} = get_update_changeset(socket, params)
    assigns = [
      enabled: enabled,
      changeset: changeset
    ]
    {:noreply, assign(socket, assigns)}
  end

  # ---- SAVE -----
  @spec handle_save(Socket.t(), map()) :: {:noreply, Socket.t()}
  defp handle_save(socket, params) do
    case socket.assigns.edit do
      :edit -> handle_edit_save(socket, params)
      :update -> handle_update_save(socket, params)
    end
  end

  @spec handle_edit_save(Socket.t(), map()) :: {:noreply, Socket.t()}
  defp handle_edit_save(socket, params) do
    type = socket.assigns.type
    changeset = get_edit_changeset(socket, params)

    {socket, assigns} = case Objects.apply_edit_changeset(changeset, type) do
                {:error, changeset, error} ->
                            assigns = [
                              changeset: changeset,
                              error: error
                            ]
                            {socket, assigns}

                {:ok, object} ->
                            PenguinMemoriesWeb.Endpoint.broadcast("refresh", "refresh", %{})
                            socket = case socket.assigns.action do
                                       :insert ->
                                         type_name = socket.assigns.type.get_type_name()
                                         url = Routes.object_list_path(socket, :index, type_name, object.id)
                                         push_patch(socket, to: url)
                                       _ ->
                                         socket
                                     end
                            assigns = [
                              edit: nil,
                              changeset: nil,
                              error: nil,
                              enabled: nil,
                            ]
                            {socket, assigns}
              end

    {:noreply, assign(socket, assigns)}
  end

  @spec handle_update_save(Socket.t(), map()) :: {:noreply, Socket.t()}
  defp handle_update_save(socket, params) do
    type = socket.assigns.type
    selected_ids = socket.assigns.selected_ids

    {enabled, changeset} = get_update_changeset(socket, params)


    {socket, assigns} = case Objects.apply_update_changeset(selected_ids, changeset, enabled, type) do
                          {:error, error} ->
                            assigns = [
                              error: error
                            ]
                            {socket, assigns}

                          :ok ->
                            PenguinMemoriesWeb.Endpoint.broadcast("refresh", "refresh", %{})
                            assigns = [
                              edit: nil,
                              changeset: nil,
                              error: nil,
                              enabled: nil,
                            ]
                            {socket, assigns}
                        end

    {:noreply, assign(socket, assigns)}
  end

  @spec output_field(Objects.Field.t(), keyword()) :: any()
  defp output_field(field, opts \\ [])
  defp output_field(%{display: nil}, _opts), do: ""
  defp output_field(field, _opts) do
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

  @spec input_field(Socket.t(), Phoenix.HTML.Form.t(), Objects.Field.t(), keyword()) :: any()
  defp input_field(socket, form, field, opts \\ []) do
    case field.type do
      :markdown ->
        textarea_input_field(form, field.id, opts)
      :album ->
        type = Objects.get_for_type("album")
        live_component(socket, PenguinMemoriesWeb.ObjectSelectComponent, type: type, form: form, field: field, id: field.id)
      _ ->
        text_input_field(form, field.id, opts)
    end
  end

  @spec field_to_enable_field_id(Objects.Field.t()) :: atom()
  defp field_to_enable_field_id(field) do
    String.to_atom(Atom.to_string(field.id) <> "_enable")
  end

end
