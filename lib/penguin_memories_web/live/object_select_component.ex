defmodule PenguinMemoriesWeb.ObjectSelectComponent do
  @moduledoc """
  Live component to select a object id
  """
  alias Ecto.Changeset

  use PenguinMemoriesWeb, :live_component
  import Phoenix.HTML.Form

  alias PenguinMemories.Database.Query
  alias PenguinMemories.Database.Query.Field
  alias PenguinMemories.Database.Query.Filter
  alias PenguinMemories.Database.Query.Icon

  @impl true
  def mount(socket) do
    assigns = [
      choices: [],
      selected: [],
      text: ""
    ]

    {:ok, assign(socket, assigns)}
  end

  @impl true
  @spec update(
          %{disabled: any, field: atom | %{icons: any}, form: any, single_choice: any, type: any},
          Phoenix.LiveView.Socket.t()
        ) :: {:ok, Phoenix.LiveView.Socket.t()}
  def update(params, socket) do
    type = params.type
    form = params.form
    field = params.field
    search = Map.get(params, :search, %{})
    selected = Changeset.get_field(form.source, field.id)

    ids =
      cond do
        is_integer(selected) ->
          [selected]

        is_binary(selected) ->
          selected
          |> String.split(",")
          |> Enum.map(fn id ->
            {id, ""} = Integer.parse(id)
            id
          end)

        is_nil(selected) ->
          []
      end
      |> MapSet.new()

    icons = Query.query_icons_by_id_map(ids, 100, type, "thumb")

    assigns = [
      type: type,
      form: form,
      field: field,
      selected: icons,
      disabled: params.disabled,
      single_choice: params.single_choice,
      search: search
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
        |> Enum.map(fn icon -> icon.id end)
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
      {id, ""} = Integer.parse(id)
      [icon | _] = socket.assigns.choices |> Enum.filter(fn icon -> icon.id == id end)
      selected = add_selected(socket.assigns.selected, icon, socket.assigns.single_choice)
      changeset = update_changeset(socket, selected)

      assigns = [
        choices: [],
        form: %{socket.assigns.form | source: changeset},
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
      [icon | _] = socket.assigns.selected |> Enum.filter(fn icon -> icon.id == id end)
      selected = remove_selected(socket.assigns.selected, icon, socket.assigns.single_choice)
      changeset = update_changeset(socket, selected)

      assigns = [
        choices: [],
        form: %{socket.assigns.form | source: changeset},
        selected: selected,
        text: ""
      ]

      {:noreply, assign(socket, assigns)}
    end
  end

  @spec add_selected(list(Icon.t()), Icon.t(), boolean()) ::
          list(Icon.t())
  def add_selected(_selected, icon, true) do
    [icon]
  end

  def add_selected(selected, icon, false) do
    [icon | selected]
  end

  @spec remove_selected(list(Icon.t()), Icon.t(), boolean()) ::
          list(Icon.t())
  def remove_selected(_selected, _icon, true) do
    []
  end

  def remove_selected(selected, icon, false) do
    Enum.reject(selected, fn s -> s.id == icon.id end)
  end

  @spec update_changeset(Phoenix.LiveView.Socket.t(), list(Icon.t())) :: Changeset.t()
  def update_changeset(socket, selected) do
    ids =
      selected
      |> Enum.map(fn icon -> icon.id end)
      |> Enum.join(",")

    Changeset.put_change(socket.assigns.form.source, socket.assigns.field.id, ids)
  end
end
