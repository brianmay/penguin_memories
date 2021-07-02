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
  alias PenguinMemories.Photos

  @impl true
  def mount(socket) do
    assigns = [
      choices: [],
      selected: [],
      icons: %{},
      edit: nil,
      text: "",
      error: nil,
      disabled: true
    ]

    {:ok, assign(socket, assigns)}
  end

  @spec get_person_id(Changeset.t() | Photos.PhotoPerson.t()) :: integer()
  defp get_person_id(%Changeset{} = changeset) do
    Ecto.Changeset.get_field(changeset, :person_id)
  end

  defp get_person_id(%Photos.PhotoPerson{} = value) do
    value.person_id
  end

  @spec get_position(Changeset.t() | Photos.PhotoPerson.t()) :: integer()
  defp get_position(%Changeset{} = changeset) do
    Ecto.Changeset.get_field(changeset, :position)
  end

  defp get_position(%Photos.PhotoPerson{} = value) do
    value.position
  end

  @spec get_new_position(map()) :: integer()
  def get_new_position(selected) do
    case Enum.max_by(selected, fn {_, v} -> get_position(v) end, fn -> nil end) do
      nil -> 1
      {_, max} -> get_position(max) + 1
    end
  end

  @impl true
  @spec update(
          %{
            disabled: boolean(),
            field: Field.t(),
            form: Form.t(),
            updates: {module(), String.t()},
            error: nil
          },
          Phoenix.LiveView.Socket.t()
        ) :: {:ok, Phoenix.LiveView.Socket.t()}
  def update(params, socket) do
    type = PenguinMemories.Photos.Person
    form = params.form
    field = params.field
    updates = params.updates
    search = Map.get(params, :search, %{})

    selected =
      Changeset.get_field(form.source, field.id)
      |> Enum.map(fn v -> {get_person_id(v), v} end)
      |> Enum.into(%{})

    icons =
      selected
      |> Enum.map(fn {person_id, _} -> person_id end)
      |> MapSet.new()
      |> Query.query_icons_by_id_map(100, type, "thumb")
      |> Enum.map(fn icon -> {icon.id, icon} end)
      |> Enum.into(%{})

    icons = Map.merge(socket.assigns.icons, icons)

    position = get_new_position(selected)

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

    assigns =
      if params.disabled do
        [{:choices, []}, {:text, nil}, {:error, nil} | assigns]
      else
        assigns
      end

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
        |> Enum.map(fn {person_id, _} -> person_id end)
        |> MapSet.new()

      case Query.query_icons(search, 10, type, "thumb") do
        {:ok, icons} ->
          icons = Enum.reject(icons, fn icon -> MapSet.member?(selected, icon.id) end)

          assigns = [
            choices: icons,
            text: value
          ]

          {:noreply, assign(socket, assigns)}

        {:error, reason} ->
          assigns = [
            choices: [],
            text: value,
            error: reason
          ]

          {:noreply, assign(socket, assigns)}
      end
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
          edit = %{
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

      edit = %{
        person_id: id,
        position: position
      }

      assigns = [
        choices: [],
        icons: icons,
        edit: edit,
        error: nil
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
      value = Map.fetch!(socket.assigns.selected, id)

      edit = %{
        person_id: id,
        position: get_position(value)
      }

      assigns = [
        choices: [],
        text: "",
        edit: edit,
        error: nil
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
        edit: nil,
        error: nil
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

      changeset =
        %Photos.PhotoPerson{}
        |> Ecto.Changeset.cast(edit, [:person_id, :position])
        |> Ecto.Changeset.unique_constraint([:photo_id, :person_id])
        |> Ecto.Changeset.unique_constraint([:photo_id, :position])

      selected = Map.put(socket.assigns.selected, edit.person_id, changeset)
      notify(socket, selected)

      position = get_new_position(selected)

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

      selected = Map.delete(socket.assigns.selected, edit.person_id)
      notify(socket, selected)

      position = get_new_position(selected)

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

  @spec notify(Phoenix.LiveView.Socket.t(), %{integer() => any()}) :: Changeset.t()
  def notify(socket, selected) do
    pid = socket.assigns.updates
    selected = Enum.map(selected, fn {_, v} -> v end)
    send(pid, {:selected, socket.assigns.field.id, selected})
  end
end
