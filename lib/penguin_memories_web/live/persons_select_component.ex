defmodule PenguinMemoriesWeb.PersonsSelectComponent do
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
      edit: nil,
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
            updates: {module(), String.t()}
          },
          Phoenix.LiveView.Socket.t()
        ) :: {:ok, Phoenix.LiveView.Socket.t()}
  def update(params, socket) do
    type = PenguinMemories.Photos.Person
    form = params.form
    field = params.field
    updates = params.updates
    search = Map.get(params, :search, %{})

    selected = Changeset.get_field(form.source, field.id)

    icons =
      selected
      |> Enum.map(fn obj -> obj.person_id end)
      |> MapSet.new()
      |> Query.query_icons_by_id_map(100, type, "thumb")
      |> Enum.map(fn icon -> {icon.id, icon} end)
      |> Enum.into(%{})

    icons = Map.merge(socket.assigns.icons, icons)

    position =
      case Enum.max_by(selected, fn v -> v.position end, fn -> nil end) do
        nil -> 1
        max -> max.position + 1
      end

    assigns = [
      form: form,
      field: field,
      selected: selected,
      icons: icons,
      disabled: params.disabled,
      search: search,
      updates: updates,
      position: position
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
      type = PenguinMemories.Photos.Person

      selected =
        socket.assigns.selected
        |> Enum.map(fn selected -> selected.person_id end)
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

  def handle_event("position", %{"value" => value}, socket) do
    position =
      case Integer.parse(value) do
        {value, ""} -> value
        _ -> socket.assigns.position
      end

    socket =
      case socket.assigns.edit do
        nil ->
          assign(socket, position: position)

        edit ->
          edit = %PenguinMemories.Photos.PhotoPerson{
            person_id: edit.person_id,
            position: position
          }

          assign(socket, edit: edit)
      end

    {:noreply, socket}
  end

  @impl true
  def handle_event("set", %{"id" => id}, socket) do
    if socket.assigns.disabled do
      {:noreply, socket}
    else
      position = socket.assigns.position
      {id, ""} = Integer.parse(id)
      [icon | _] = socket.assigns.choices |> Enum.filter(fn icon -> icon.id == id end)
      icons = add_icon(socket.assigns.icons, icon)

      edit = %PenguinMemories.Photos.PhotoPerson{
        person_id: id,
        position: position
      }

      assigns = [
        choices: [],
        icons: icons,
        edit: edit
      ]

      {:noreply, assign(socket, assigns)}
    end
  end

  @impl true
  def handle_event("edit", %{"id" => id}, socket) do
    if socket.assigns.disabled do
      {:noreply, socket}
    else
      {id, ""} = Integer.parse(id)
      [edit | _] = socket.assigns.selected |> Enum.filter(fn pp -> pp.person_id == id end)

      assigns = [
        choices: [],
        text: "",
        edit: edit
      ]

      {:noreply, assign(socket, assigns)}
    end
  end

  @impl true
  def handle_event("unedit", _, socket) do
    if socket.assigns.disabled do
      {:noreply, socket}
    else
      assigns = [
        choices: [],
        text: "",
        edit: nil
      ]

      {:noreply, assign(socket, assigns)}
    end
  end

  @impl true
  def handle_event("commit", _, socket) do
    if socket.assigns.disabled do
      {:noreply, socket}
    else
      edit = socket.assigns.edit

      selected =
        socket.assigns.selected
        |> Enum.reject(fn pp -> pp.person_id == edit.person_id end)

      selected = [edit | selected]
      selected = Enum.sort_by(selected, fn pp -> pp.position end)

      notify(socket, selected)

      position =
        case Enum.max_by(selected, fn v -> v.position end, fn -> nil end) do
          nil -> 1
          max -> max.position + 1
        end

      assigns = [
        selected: selected,
        text: "",
        edit: nil,
        position: position
      ]

      {:noreply, assign(socket, assigns)}
    end
  end

  @impl true
  def handle_event("delete", _, socket) do
    if socket.assigns.disabled do
      {:noreply, socket}
    else
      edit = socket.assigns.edit

      selected =
        socket.assigns.selected
        |> Enum.reject(fn pp -> pp.person_id == edit.person_id end)

      notify(socket, selected)

      position =
        case Enum.max_by(selected, fn v -> v.position end, fn -> nil end) do
          nil -> 1
          max -> max.position + 1
        end

      assigns = [
        selected: selected,
        edit: nil,
        position: position
      ]

      {:noreply, assign(socket, assigns)}
    end
  end

  @spec add_icon(%{integer() => Icon.t()}, Icon.t()) :: %{integer() => Icon.t()}
  def add_icon(icons, %Icon{} = icon) do
    Map.put(icons, icon.id, icon)
  end

  @spec remove_icon(%{integer() => Icon.t()}, integer()) :: %{integer() => Icon.t()}
  def remove_icon(icons, id) do
    Map.delete(icons, id)
  end

  @spec add_selection(list(struct()), integer(), integer()) :: list(struct())
  def add_selection(selections, id, position) do
    selections = Enum.reject(selections, fn s -> s.person_id == id end)

    new_selection = %PenguinMemories.Photos.PhotoPerson{
      person_id: id,
      position: position
    }

    [new_selection | selections]
  end

  @spec remove_selection(list(struct()), integer()) :: list(struct())
  def remove_selection(selections, id) do
    Enum.reject(selections, fn s -> s.person_id == id end)
  end

  @spec notify(Phoenix.LiveView.Socket.t(), list(Icon.t())) :: Changeset.t()
  def notify(socket, selected) do
    pid = socket.assigns.updates
    send(pid, {:selected, socket.assigns.field.id, selected})
  end
end
