defmodule PenguinMemoriesWeb.PersonsSelectComponent do
  @moduledoc """
  Live component to select a object id
  """
  alias Ecto.Changeset

  use PenguinMemoriesWeb, :live_component

  import Phoenix.HTML.Form
  alias Phoenix.HTML.Form
  alias Phoenix.LiveView.Socket

  alias PenguinMemories.Database.Fields.Field
  alias PenguinMemories.Database.Query
  alias PenguinMemories.Database.Query.Filter
  alias PenguinMemories.Database.Query.Icon
  alias PenguinMemories.Photos

  @impl true
  def mount(socket) do
    assigns = [
      choices: [],
      base: %{},
      selected: %{},
      icons: %{},
      text: "",
      error: nil,
      disabled: true
    ]

    {:ok, assign(socket, assigns)}
  end

  @type change_type :: Changeset.t() | Photos.PhotoPerson.t()

  @spec get_person_id(change_type()) :: integer()
  defp get_person_id(%Changeset{} = changeset) do
    Ecto.Changeset.get_field(changeset, :person_id)
  end

  defp get_person_id(%Photos.PhotoPerson{} = value) do
    value.person_id
  end

  @spec is_update(change_type()) :: integer()
  defp is_update(%Changeset{} = changeset) do
    changeset.action == :update
  end

  defp is_update(%Photos.PhotoPerson{}) do
    true
  end

  @spec get_position(change_type()) :: integer()
  defp get_position(%Changeset{} = changeset) do
    Ecto.Changeset.get_field(changeset, :position)
  end

  defp get_position(%Photos.PhotoPerson{} = value) do
    value.position
  end

  @spec get_new_position(%{integer => change_type()}) :: integer()
  def get_new_position(selected) do
    case Enum.max_by(selected, fn {_, v} -> get_position(v) end, fn -> nil end) do
      nil -> 1
      {_, max} -> get_position(max) + 1
    end
  end

  @spec get_sorted(selected :: %{integer => change_type()}) :: list(change_type())
  defp get_sorted(selected) do
    # Sort by person_id because it is deterministic and doesn't
    # keep changing (unlike position).
    # Sorting by position would in theory be better, but means the fields
    # jump around causing endless UI problems.
    selected
    |> Enum.map(fn {_, pp} -> pp end)
    |> Enum.sort_by(fn value -> get_person_id(value) end)
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

    source = Map.fetch!(form.source.data, field.id)

    base =
      source
      |> Enum.map(fn v -> {v.person_id, v} end)
      |> Enum.into(%{})

    selected =
      Changeset.get_change(form.source, field.id, source)
      |> Enum.filter(fn changeset -> is_update(changeset) end)
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

    new_position = get_new_position(selected)

    assigns = [
      form: form,
      field: field,
      base: base,
      selected: selected,
      icons: icons,
      disabled: Map.get(params, :disabled, false),
      search: search,
      updates: updates,
      new_position: new_position
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
  def handle_event("new_search", %{"value" => value}, socket) do
    search = %Filter{query: value}

    if socket.assigns.disabled or value == "" do
      assigns = [
        choices: [],
        text: value
      ]

      {:noreply, assign(socket, assigns)}
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

  def handle_event("new_position", %{"value" => value}, socket) do
    position =
      case Integer.parse(value) do
        {value, ""} -> value
        _ -> nil
      end

    socket =
      if position != nil do
        assign(socket, new_position: position)
      else
        socket
      end

    {:noreply, socket}
  end

  def handle_event("position", %{"person-id" => person_id, "value" => value}, socket) do
    person_id =
      case Integer.parse(person_id) do
        {value, ""} -> value
        _ -> nil
      end

    position =
      case Integer.parse(value) do
        {value, ""} -> value
        _ -> nil
      end

    socket =
      if person_id != nil and position != nil do
        commit(socket, person_id, position)
      else
        assign(socket, error: "Invalid values")
      end

    {:noreply, socket}
  end

  @impl true
  def handle_event("set", %{"id" => id}, socket) do
    socket =
      if socket.assigns.disabled do
        socket
      else
        position = socket.assigns.new_position

        person_id =
          case Integer.parse(id) do
            {value, ""} -> value
            _ -> nil
          end

        [icon | _] = socket.assigns.choices |> Enum.filter(fn icon -> icon.id == person_id end)
        icons = add_icon(socket.assigns.icons, icon)

        assigns = [
          choices: [],
          text: "",
          icons: icons,
          error: nil
        ]

        socket
        |> assign(assigns)
        |> commit(person_id, position)
      end

    {:noreply, socket}
  end

  @impl true
  def handle_event("delete", %{"person-id" => person_id}, socket) do
    if socket.assigns.disabled do
      {:noreply, socket}
    else
      person_id =
        case Integer.parse(person_id) do
          {value, ""} -> value
          _ -> nil
        end

      selected = Map.delete(socket.assigns.selected, person_id)
      notify(socket, selected)

      new_position = get_new_position(selected)

      assigns = [
        selected: selected,
        new_position: new_position
      ]

      {:noreply, assign(socket, assigns)}
    end
  end

  @spec commit(socket :: Socket.t(), person_id :: integer(), position :: integer()) :: Socket.t()
  def commit(%Socket{} = socket, person_id, position) do
    if socket.assigns.disabled do
      socket
    else
      edit = %{person_id: person_id, position: position}

      base_object =
        case Map.fetch(socket.assigns.base, person_id) do
          {:ok, %Changeset{data: data}} -> data
          {:ok, value} -> value
          :error -> %Photos.PhotoPerson{}
        end

      changeset =
        base_object
        |> Ecto.Changeset.cast(edit, [:person_id, :position])
        |> Ecto.Changeset.unique_constraint([:photo_id, :person_id])
        |> Ecto.Changeset.unique_constraint([:photo_id, :position])

      selected = Map.put(socket.assigns.selected, person_id, changeset)
      notify(socket, selected)

      new_position = get_new_position(selected)

      assigns = [
        selected: selected,
        new_position: new_position,
        error: nil
      ]

      assign(socket, assigns)
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
