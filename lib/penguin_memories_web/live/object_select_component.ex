defmodule PenguinMemoriesWeb.ObjectSelectComponent do
  @moduledoc """
  Live component to select a object id
  """
  alias Ecto.Changeset

  use PenguinMemoriesWeb, :live_component

  import Phoenix.HTML.Form
  alias Phoenix.HTML.Form

  alias PenguinMemories.Database.Query
  alias PenguinMemories.Database.Query.Field
  alias PenguinMemories.Database.Query.Filter
  alias PenguinMemories.Database.Query.Icon

  @impl true
  def mount(socket) do
    assigns = [
      choices: [],
      selected: [],
      icons: [],
      text: ""
    ]

    {:ok, assign(socket, assigns)}
  end

  @impl true
  @spec update(
          %{
            disabled: boolean(),
            field: Field.t(),
            form: Form.t(),
            single_choice: boolean(),
            type: Query.object_type(),
            updates: {module(), String.t()}
          },
          Phoenix.LiveView.Socket.t()
        ) :: {:ok, Phoenix.LiveView.Socket.t()}
  def update(params, socket) do
    type = params.type
    form = params.form
    field = params.field
    single_choice = params.single_choice
    updates = params.updates
    search = Map.get(params, :search, %{})

    raw_value = Changeset.get_field(form.source, field.id)

    selected =
      case {single_choice, raw_value} do
        {true, nil} -> []
        {true, value} -> [value]
        {false, _} -> raw_value
      end

    icons =
      selected
      |> Enum.map(fn obj -> obj.id end)
      |> Enum.into(MapSet.new())
      |> Query.query_icons_by_id_map(100, type, "thumb")

    assigns = [
      type: type,
      form: form,
      field: field,
      selected: selected,
      icons: icons,
      disabled: params.disabled,
      single_choice: params.single_choice,
      search: search,
      updates: updates
    ]

    {:ok, assign(socket, assigns)}
  end

  @spec field_to_dummy_field_id(Field.t()) :: atom()
  defp field_to_dummy_field_id(field) do
    String.to_atom(Atom.to_string(field.id) <> "_dummy")
  end

  @impl true
  def handle_event("search", %{"value" => value}, socket) do
    search = %Filter{query: value}

    if socket.assigns.disabled do
      {:noreply, socket}
    else
      type = socket.assigns.type

      icons =
        socket.assigns.icons
        |> Enum.map(fn icon -> icon.id end)
        |> MapSet.new()

      icons =
        search
        |> Query.query_icons(10, type, "thumb")
        |> Enum.reject(fn icon -> MapSet.member?(icons, icon.id) end)

      assigns = [
        choices: icons,
        text: value
      ]

      {:noreply, assign(socket, assigns)}
    end
  end

  @impl true
  def handle_event("add", %{"id" => id}, socket) do
    if socket.assigns.disabled do
      {:noreply, socket}
    else
      type = socket.assigns.type
      {id, ""} = Integer.parse(id)
      [icon | _] = socket.assigns.choices |> Enum.filter(fn icon -> icon.id == id end)
      icons = add_icons(socket.assigns.icons, icon, socket.assigns.single_choice)
      selected = add_selection(socket.assigns.selected, id, socket.assigns.single_choice, type)
      update_changeset(socket, selected)

      assigns = [
        choices: [],
        # form: %{socket.assigns.form | source: changeset},
        icons: icons,
        text: ""
      ]

      {:noreply, assign(socket, assigns)}
    end
  end

  @impl true
  def handle_event("remove", %{"id" => id}, socket) do
    if socket.assigns.disabled do
      {:noreply, socket}
    else
      {id, ""} = Integer.parse(id)
      [icon | _] = socket.assigns.icons |> Enum.filter(fn icon -> icon.id == id end)
      icons = remove_icons(socket.assigns.icons, icon, socket.assigns.single_choice)
      selected = remove_selection(socket.assigns.selected, id, socket.assigns.single_choice)
      update_changeset(socket, selected)

      assigns = [
        choices: [],
        # form: %{socket.assigns.form | source: changeset},
        icons: icons,
        text: ""
      ]

      {:noreply, assign(socket, assigns)}
    end
  end

  @spec add_icons(list(Icon.t()), Icon.t(), boolean()) ::
          list(Icon.t())
  def add_icons(_icons, %Icon{} = icon, true) do
    [icon]
  end

  def add_icons(icons, %Icon{} = icon, false) do
    icons = Enum.reject(icons, fn s -> s.id == icon.id end)
    [icon | icons]
  end

  @spec remove_icons(list(Icon.t()), Icon.t(), boolean()) ::
          list(Icon.t())
  def remove_icons(icons, %Icon{} = icon, _) do
    Enum.reject(icons, fn s -> s.id == icon.id end)
  end

  @spec add_selection(list(struct()), integer(), boolean(), type :: Query.object_type()) ::
          list(struct())
  def add_selection(_selections, id, true, type) do
    case Query.get_object_by_id(id, type) do
      nil -> []
      obj -> [obj]
    end
  end

  def add_selection(selections, id, false, type) do
    selections = Enum.reject(selections, fn s -> s.id == id end)

    case Query.get_object_by_id(id, type) do
      nil -> selections
      obj -> [obj | selections]
    end
  end

  @spec remove_selection(list(struct()), integer(), boolean()) ::
          list(struct())
  def remove_selection(selections, id, _) do
    Enum.reject(selections, fn s -> s.id == id end)
  end

  @spec update_changeset(Phoenix.LiveView.Socket.t(), list(Icon.t())) :: Changeset.t()
  def update_changeset(socket, selected) do
    value =
      case {socket.assigns.single_choice, selected} do
        {true, []} -> nil
        {true, [v]} -> v
        {false, v} -> v
      end

    {module, id} = socket.assigns.updates
    # IO.inspect(socket.assigns.updates)
    # IO.inspect(self())
    # send(socket.assigns.updates, {:selected, socket.assigns.field.id, value})
    send_update(module, id: id, status: :selected, field_id: socket.assigns.field.id, value: value)

    # IO.inspect(value)
    # Changeset.put_change(socket.assigns.form.source, socket.assigns.field.id, value) |> IO.inspect()
  end
end
