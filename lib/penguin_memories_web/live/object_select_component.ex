defmodule PenguinMemoriesWeb.ObjectSelectComponent do
  @moduledoc """
  Live component to select a object id
  """
  alias Ecto.Changeset

  use PenguinMemoriesWeb, :live_component

  import Phoenix.HTML.Form
  alias Phoenix.HTML.Form

  alias PenguinMemories.Database.Fields.Field
  alias PenguinMemories.Database.Query
  alias PenguinMemories.Database.Query.Filter
  alias PenguinMemories.Database.Query.Icon

  @impl true
  def mount(socket) do
    assigns = [
      choices: [],
      selected: [],
      icons: %{},
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
            updates: pid()
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
        {_, nil} -> []
        {true, value} -> [value]
        {false, _} -> raw_value
      end

    icons =
      selected
      |> Enum.map(fn obj -> obj.id end)
      |> Enum.into(MapSet.new())
      |> Query.query_icons_by_id_map(100, type, "thumb")
      |> Enum.map(fn icon -> {icon.id, icon} end)
      |> Enum.into(%{})

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

      selected =
        socket.assigns.selected
        |> Enum.map(fn selected -> selected.id end)
        |> MapSet.new()

      icons =
        search
        |> Query.query_icons(10, type, "thumb")
        |> Enum.reject(fn icon -> MapSet.member?(selected, icon.id) end)

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
      icons = add_icon(socket.assigns.icons, icon)
      selected = add_selection(socket.assigns.selected, id, socket.assigns.single_choice, type)
      notify(socket, selected)

      assigns = [
        choices: [],
        # form: %{socket.assigns.form | source: changeset},
        icons: icons,
        selected: selected,
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
      icons = remove_icon(socket.assigns.icons, id)
      selected = remove_selection(socket.assigns.selected, id, socket.assigns.single_choice)
      notify(socket, selected)

      assigns = [
        choices: [],
        # form: %{socket.assigns.form | source: changeset},
        icons: icons,
        selected: selected,
        text: ""
      ]

      {:noreply, assign(socket, assigns)}
    end
  end

  @spec add_icon(%{integer() => Icon.t()}, Icon.t()) :: %{integer() => Icon.t()}
  defp add_icon(icons, %Icon{} = icon) do
    Map.put(icons, icon.id, icon)
  end

  @spec remove_icon(%{integer() => Icon.t()}, integer()) :: %{integer() => Icon.t()}
  def remove_icon(icons, id) do
    Map.delete(icons, id)
  end

  @spec add_selection(list(struct()), integer(), boolean(), type :: Query.object_type()) ::
          list(struct())
  defp add_selection(_selections, id, true, type) do
    case Query.get_object_by_id(id, type) do
      nil -> []
      obj -> [obj]
    end
  end

  defp add_selection(selections, id, false, type) do
    selections = Enum.reject(selections, fn s -> s.id == id end)

    case Query.get_object_by_id(id, type) do
      nil -> selections
      obj -> [obj | selections]
    end
  end

  @spec remove_selection(list(struct()), integer(), boolean()) ::
          list(struct())
  defp remove_selection(selections, id, _) do
    Enum.reject(selections, fn s -> s.id == id end)
  end

  @spec notify(Phoenix.LiveView.Socket.t(), list(Icon.t())) :: Changeset.t()
  defp notify(socket, selected) do
    value =
      case {socket.assigns.single_choice, selected} do
        {true, []} -> nil
        {true, [v]} -> v
        {false, v} -> v
      end

    pid = socket.assigns.updates
    send(pid, {:selected, socket.assigns.field.id, value})
  end
end
