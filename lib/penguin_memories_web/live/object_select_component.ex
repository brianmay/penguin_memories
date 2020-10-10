defmodule PenguinMemoriesWeb.ObjectSelectComponent do
  @moduledoc """
  Live component to select a object id
  """
  alias Ecto.Changeset

  use PenguinMemoriesWeb, :live_component
  import Phoenix.HTML.Form

  alias PenguinMemories.Objects

  @impl true
  def mount(socket) do
    assigns = [
      choices: [],
      text: ""
    ]
    {:ok, assign(socket, assigns)}
  end

  @impl true
  def update(params, socket) do
    type = params.type
    form = params.form
    field = params.field
    id = Changeset.get_field(form.source, field.id)

    assigns = [
      type: type,
      form: form,
      field: field,
      selected_id: id,
      selected_display: field.display
    ]

    {:ok, assign(socket, assigns)}
  end

  @spec field_to_dummy_field_id(Objects.Field.t()) :: atom()
  defp field_to_dummy_field_id(field) do
    String.to_atom(Atom.to_string(field.id) <> "_dummy")
  end

  @impl true
  def handle_event("search", %{"value" => value}, socket) do
    type = socket.assigns.type
    icons = type.search_icons(%{"query" => value}, nil, 10)
    assigns = [
      choices: icons,
      text: value
    ]
    {:noreply, assign(socket, assigns)}
  end

  @impl true
  def handle_event("select", %{"id" => id}, socket) do
    {id, ""} = Integer.parse(id)
    changeset = Changeset.put_change(socket.assigns.form.source, socket.assigns.field.id, id)
    [icon | _] = socket.assigns.choices |> Enum.filter(fn icon -> icon.id == id end)
    assigns = [
      choices: [],
      form: %{socket.assigns.form | source: changeset},
      selected_id: id,
      selected_display: Objects.get_title(icon.title, icon.id),
      text: ""
    ]
    {:noreply, assign(socket, assigns)}
  end

  @impl true
  def handle_event("remove", _param, socket) do
    changeset = Changeset.put_change(socket.assigns.form.source, socket.assigns.field.id, nil)
    assigns = [
      choices: [],
      form: %{socket.assigns.form | source: changeset},
      selected_id: nil,
      selected_display: nil,
      text: ""
    ]
    {:noreply, assign(socket, assigns)}
  end

  @impl true
  def handle_event("blur", _param, socket) do
    assigns = [
      # choices: []
    ]
    {:noreply, assign(socket, assigns)}
  end

end
