defmodule PenguinMemoriesWeb.ObjectDetailComponent do
  @moduledoc """
  Live component to display/edit details of a component.
  """
  use PenguinMemoriesWeb, :live_component

  alias Ecto.Changeset
  alias PenguinMemories.Auth
  alias PenguinMemories.Database.Query
  alias PenguinMemories.Database.Query.Field
  alias PenguinMemories.Database.Query.Icon
  alias PenguinMemories.Database.Types
  alias PenguinMemories.Format
  alias Phoenix.LiveView.Socket

  @impl true
  def mount(%Socket{} = socket) do
    assigns = [
      edit: nil,
      edit_object: nil,
      enabled: nil,
      action: nil,
      changeset: nil,
      error: nil,
      selected_object: nil,
      user: nil,
      videos: nil,
      big: false
    ]

    {:ok, assign(socket, assigns)}
  end

  @impl true
  def update(%{status: "refresh"}, %Socket{} = socket) do
    socket = reload(socket)
    {:ok, socket}
  end

  def update(%{status: :selected} = change, %Socket{} = socket) do
    assoc = Map.put(socket.assigns.assoc, change.field_id, change.value)
    socket = assign(socket, assoc: assoc)
    {:ok, socket}
  end

  @impl true
  def update(params, %Socket{} = socket) do
    type = params.type
    selected_ids = params.selected_ids
    num_selected = MapSet.size(selected_ids)

    assigns = [
      id: params.id,
      type: type,
      num_selected: num_selected,
      selected_ids: selected_ids,
      error: nil,
      edit: nil,
      edit_object: nil,
      enabled: nil,
      action: nil,
      user: params.user,
      filter: params.filter
    ]

    socket =
      socket
      |> assign(assigns)
      |> reload()

    {:ok, socket}
  end

  def reload(%Socket{} = socket) do
    type = socket.assigns.type
    num_selected = socket.assigns.num_selected
    selected_ids = socket.assigns.selected_ids
    filter = socket.assigns.filter

    {icon_size, video_size} =
      case socket.assigns.big do
        false -> {"mid", "mid"}
        true -> {"large", "large"}
      end

    {selected_object, selected_fields, icons, more_icons, prev_icon, next_icon, videos} =
      cond do
        num_selected == 0 ->
          {nil, nil, [], false, nil, nil, []}

        num_selected == 1 ->
          [id] = MapSet.to_list(selected_ids)

          case Query.get_details(id, icon_size, video_size, type) do
            nil ->
              {nil, nil, [], false, nil, nil, []}

            %Query.Details{} = details ->
              prev_icon = Query.get_prev_next_id(filter, details.cursor, nil, "thumb", type)
              next_icon = Query.get_prev_next_id(filter, nil, details.cursor, "thumb", type)

              {details.obj, details.fields, [details.icon], false, prev_icon, next_icon,
               details.videos}
          end

        true ->
          limit = 5
          icons = Query.query_icons_by_id_map(selected_ids, limit, type, "thumb")
          fields = Query.get_update_fields(type)
          {nil, fields, icons, length(icons) >= limit, nil, nil, []}
      end

    assigns = [
      selected_object: selected_object,
      selected_fields: selected_fields,
      more_icons: more_icons,
      icons: icons,
      prev_icon: prev_icon,
      next_icon: next_icon,
      videos: videos
    ]

    assign(socket, assigns)
  end

  @spec handle_event(String.t(), map, Phoenix.LiveView.Socket.t()) ::
          {:noreply, Phoenix.LiveView.Socket.t()}
  def handle_event("create", _params, %Socket{} = socket) do
    if Auth.can_edit(socket.assigns.user) do
      handle_create(socket)
    else
      {:noreply, assign(socket, :error, "Permission denied")}
    end
  end

  @impl true
  def handle_event("big", _params, %Socket{} = socket) do
    {:noreply, assign(socket, :big, true) |> reload()}
  end

  @impl true
  def handle_event("unbig", _params, %Socket{} = socket) do
    {:noreply, assign(socket, :big, false) |> reload()}
  end

  @impl true
  def handle_event("edit", _params, %Socket{} = socket) do
    if Auth.can_edit(socket.assigns.user) do
      handle_edit(socket)
    else
      {:noreply, assign(socket, :error, "Permission denied")}
    end
  end

  @impl true
  def handle_event("update", _params, %Socket{} = socket) do
    if Auth.can_edit(socket.assigns.user) do
      handle_update(socket)
    else
      {:noreply, assign(socket, :error, "Permission denied")}
    end
  end

  @impl true
  def handle_event("delete", _params, %Socket{} = socket) do
    if Auth.can_edit(socket.assigns.user) do
      handle_delete(socket)
    else
      {:noreply, assign(socket, :error, "Permission denied")}
    end
  end

  @impl true
  def handle_event("validate", %{"object" => params}, %Socket{} = socket) do
    if Auth.can_edit(socket.assigns.user) do
      handle_validate(socket, params)
    else
      {:noreply, assign(socket, :error, "Permission denied")}
    end
  end

  @impl true
  def handle_event("save", %{"object" => params}, %Socket{} = socket) do
    if Auth.can_edit(socket.assigns.user) do
      handle_save(socket, params)
    else
      {:noreply, assign(socket, :error, "Permission denied")}
    end
  end

  @impl true
  def handle_event("cancel", _params, %Socket{} = socket) do
    assigns = [
      edit: nil,
      changeset: nil,
      error: nil,
      enabled: nil
    ]

    {:noreply, assign(socket, assigns)}
  end

  @spec handle_create(Socket.t()) :: {:noreply, Socket.t()}
  defp handle_create(%Socket{} = socket) do
    changeset = Query.get_create_child_changeset(socket.assigns.selected_object, %{})

    assigns = [
      edit: :edit,
      changeset: changeset,
      edit_object: changeset.data,
      action: :insert,
      assoc: %{}
    ]

    {:noreply, assign(socket, assigns)}
  end

  @spec handle_edit(Socket.t()) :: {:noreply, Socket.t()}
  defp handle_edit(%Socket{} = socket) do
    changeset = Query.get_edit_changeset(socket.assigns.selected_object, %{})
    changeset = %{changeset | action: :update}

    assigns = [
      edit: :edit,
      changeset: changeset,
      edit_object: changeset.data,
      action: :update,
      assoc: %{}
    ]

    {:noreply, assign(socket, assigns)}
  end

  @spec handle_update(Socket.t()) :: {:noreply, Socket.t()}
  defp handle_update(%Socket{} = socket) do
    type = socket.assigns.type
    enabled = MapSet.new()
    changeset = Query.get_update_changeset(enabled, %{}, type)
    changeset = %{changeset | action: :update}

    assigns = [
      edit: :update,
      changeset: changeset,
      edit_object: changeset.data,
      enabled: enabled,
      action: :update,
      assoc: %{}
    ]

    {:noreply, assign(socket, assigns)}
  end

  @spec handle_delete(Socket.t()) :: {:noreply, Socket.t()}
  defp handle_delete(%Socket{} = socket) do
    {socket, assigns} =
      case Query.delete(socket.assigns.selected_object) do
        {:error, error} ->
          assigns = [
            error: error
          ]

          {socket, assigns}

        :ok ->
          PenguinMemoriesWeb.Endpoint.broadcast("refresh", "refresh", %{})
          type_name = Types.get_name!(socket.assigns.type)
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
  defp get_edit_changeset(%Socket{} = socket, params) do
    changeset = Query.get_edit_changeset(socket.assigns.edit_object, params)
    changeset = %{changeset | action: socket.assigns.action}

    changeset =
      Enum.reduce(socket.assigns.assoc, changeset, fn {key, value}, changeset ->
        Changeset.put_assoc(changeset, key, value)
      end)

    changeset
  end

  # ---- UPDATE -----
  @spec get_update_changes(list(Field.t()), map()) :: {MapSet.t(), map()}
  def get_update_changes(fields, params) do
    Enum.reduce(fields, {MapSet.new(), %{}}, fn
      %Field{} = field, {enabled, changes} ->
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
  defp get_update_changeset(%Socket{} = socket, params) do
    type = socket.assigns.type

    {enabled, changes} = get_update_changes(socket.assigns.selected_fields, params)
    changeset = Query.get_update_changeset(enabled, changes, type)
    changeset = %{changeset | action: socket.assigns.action}

    changeset =
      Enum.reduce(socket.assigns.assoc, changeset, fn {key, value}, changeset ->
        Changeset.put_assoc(changeset, key, value)
      end)

    {enabled, changeset}
  end

  # ---- VALIDATE -----
  @spec handle_validate(Socket.t(), map()) :: {:noreply, Socket.t()}
  def handle_validate(%Socket{} = socket, params) do
    case socket.assigns.edit do
      :edit -> handle_edit_validate(socket, params)
      :update -> handle_update_validate(socket, params)
    end
  end

  @spec handle_edit_validate(Socket.t(), map()) :: {:noreply, Socket.t()}
  def handle_edit_validate(%Socket{} = socket, params) do
    changeset = get_edit_changeset(socket, params)

    assigns = [
      changeset: changeset
    ]

    {:noreply, assign(socket, assigns)}
  end

  @spec handle_update_validate(Socket.t(), map()) :: {:noreply, Socket.t()}
  def handle_update_validate(%Socket{} = socket, params) do
    {enabled, changeset} = get_update_changeset(socket, params)

    assigns = [
      enabled: enabled,
      changeset: changeset
    ]

    {:noreply, assign(socket, assigns)}
  end

  # ---- SAVE -----
  @spec handle_save(Socket.t(), map()) :: {:noreply, Socket.t()}
  defp handle_save(%Socket{} = socket, params) do
    case socket.assigns.edit do
      :edit -> handle_edit_save(socket, params)
      :update -> handle_update_save(socket, params)
    end
  end

  @spec handle_edit_save(Socket.t(), map()) :: {:noreply, Socket.t()}
  defp handle_edit_save(%Socket{} = socket, params) do
    type = socket.assigns.type
    changeset = get_edit_changeset(socket, params)

    {socket, assigns} =
      case Query.apply_edit_changeset(changeset, type) do
        {:error, changeset, error} ->
          assigns = [
            changeset: changeset,
            error: error
          ]

          {socket, assigns}

        {:ok, object} ->
          PenguinMemoriesWeb.Endpoint.broadcast("refresh", "refresh", %{})

          socket =
            case socket.assigns.action do
              :insert ->
                type_name = Types.get_name!(socket.assigns.type)
                url = Routes.object_list_path(socket, :index, type_name, object.id)
                push_patch(socket, to: url)

              _ ->
                socket
            end

          assigns = [
            edit: nil,
            changeset: nil,
            error: nil,
            enabled: nil
          ]

          {socket, assigns}
      end

    {:noreply, assign(socket, assigns)}
  end

  @spec handle_update_save(Socket.t(), map()) :: {:noreply, Socket.t()}
  defp handle_update_save(%Socket{} = socket, params) do
    type = socket.assigns.type
    selected_ids = socket.assigns.selected_ids

    {enabled, changeset} = get_update_changeset(socket, params)

    {socket, assigns} =
      case Query.apply_update_changeset(selected_ids, changeset, enabled, type) do
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
            enabled: nil
          ]

          {socket, assigns}
      end

    {:noreply, assign(socket, assigns)}
  end

  @spec display_icon(icon :: Icon.t() | nil) :: any()
  defp display_icon(nil), do: ""

  defp display_icon(%Icon{} = icon) do
    display_icons([icon])
  end

  @spec display_icons(icon :: list(Icon.t())) :: any()
  defp display_icons(icons) do
    Phoenix.View.render(PenguinMemoriesWeb.IncludeView, "icons.html",
      icons: icons,
      classes: [],
      event: "goto"
    )
  end

  @spec output_field(value :: any(), field :: Field.t()) :: any()
  defp output_field(value, field)

  defp output_field(_, %Field{type: {:static, value}}) do
    value
  end

  defp output_field(nil, _field), do: "N/A"

  defp output_field(value, %Field{type: {:single, type}}) do
    Query.query_icon_by_id(value.id, type, "thumb")
    |> display_icon()
  end

  defp output_field(value, %Field{type: {:multiple, type}}) do
    value
    |> Enum.map(fn obj -> obj.id end)
    |> Enum.into(MapSet.new())
    |> Query.query_icons_by_id_map(10, type, "thumb")
    |> display_icons()
  end

  defp output_field(value, %Field{type: :markdown}) do
    case Earmark.as_html(value) do
      {:ok, html_doc, _} ->
        Phoenix.HTML.raw(html_doc)

      {:error, _, errors} ->
        result = ["</ul>"]

        result =
          Enum.reduce(errors, result, fn {_, _, text}, acc ->
            ["<li>", text, "</li>" | acc]
          end)

        result = ["<ul class='alert alert-danger'>" | result]
        Phoenix.HTML.raw(result)
    end
  end

  defp output_field(value, %Field{type: :datetime}) do
    Format.display_datetime(value)
  end

  defp output_field(value, %Field{type: {:datetime_with_offset, utc_offset}}) do
    Format.display_datetime_offset(value, utc_offset)
  end

  defp output_field(value, _field) do
    value
  end

  @spec input_field(Socket.t(), String.t(), Phoenix.HTML.Form.t(), Field.t(), keyword()) :: any()
  defp input_field(%Socket{} = socket, id, form, %Field{} = field, opts \\ []) do
    opts = [{:label, field.title} | opts]

    case field.type do
      :markdown ->
        textarea_input_field(form, field.id, opts)

      {:single, type} ->
        disabled = opts[:disabled]

        live_component(socket, PenguinMemoriesWeb.ObjectSelectComponent,
          type: type,
          form: form,
          field: field,
          id: field.id,
          disabled: disabled,
          single_choice: true,
          updates: {__MODULE__, id}
        )

      {:multiple, type} ->
        disabled = opts[:disabled]

        live_component(socket, PenguinMemoriesWeb.ObjectSelectComponent,
          type: type,
          form: form,
          field: field,
          id: field.id,
          disabled: disabled,
          single_choice: false,
          updates: {__MODULE__, id}
        )

      {:static, _} ->
        nil

      _ ->
        text_input_field(form, field.id, opts)
    end
  end

  @spec field_to_enable_field_id(Field.t()) :: atom()
  defp field_to_enable_field_id(%Field{} = field) do
    String.to_atom(Atom.to_string(field.id) <> "_enable")
  end

  @spec get_photo_url(Socket.t(), type :: PenguinMemories.Database.object_type(), integer) ::
          String.t() | nil
  defp get_photo_url(%Socket{}, PenguinMemories.Photos.Photo, _), do: nil

  defp get_photo_url(%Socket{} = socket, type, id) do
    name = Types.get_name!(type)

    params = %{
      reference: "#{name}:#{id}"
    }

    query = URI.encode_query(params)
    Routes.object_list_path(socket, :index, "photo") <> "?" <> query
  end
end
