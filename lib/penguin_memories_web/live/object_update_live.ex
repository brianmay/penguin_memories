defmodule PenguinMemoriesWeb.ObjectUpdateLive do
  @moduledoc """
  Live view to display list of objects
  """
  use PenguinMemoriesWeb, :live_view

  alias Ecto.Changeset
  alias Elixir.Phoenix.LiveView.Socket

  alias PenguinMemories.Auth
  alias PenguinMemories.Database
  alias PenguinMemories.Database.Fields
  alias PenguinMemories.Database.Query
  alias PenguinMemories.Database.Updates
  alias PenguinMemoriesWeb.FieldHelpers
  alias PenguinMemoriesWeb.LiveRequest

  defmodule Request do
    @moduledoc """
    List of icons to display
    """
    @type selected_type :: PenguinMemoriesWeb.ObjectListLive.selected_type()

    @type t :: %__MODULE__{
            type: Database.object_type(),
            filter: Query.Filter.t()
          }
    @enforce_keys [
      :type,
      :filter
    ]
    defstruct type: nil,
              filter: nil
  end

  @impl true
  @spec mount(map(), map(), Socket.t()) :: {:ok, Socket.t()}
  def mount(_params, _session, socket) do
    assigns = [
      error: nil,
      filter: nil,
      type: nil,
      count: nil,
      changeset: nil,
      enabled: nil,
      assoc: nil,
      request: nil,
      common: %LiveRequest{
        url: nil,
        host_url: nil,
        user: nil,
        big_id: nil,
        force_reload: nil
      }
    ]

    socket = assign(socket, assigns)

    if connected?(socket) do
      send(socket.parent_pid, {:child_pid, socket.id, self()})
    end

    {:ok, socket}
  end

  def handle_info({:parameters, %LiveRequest{} = common, %Request{} = request}, socket) do
    request_changed = socket.assigns.request != request

    socket =
      LiveRequest.apply_common(socket, common)
      |> assign(request: request)

    socket =
      if request_changed or common.force_reload do
        reload(socket)
      else
        socket
      end

    {:noreply, socket}
  end

  @impl true
  def handle_info({:selected, id, value}, %Socket{} = socket) do
    assoc = Map.put(socket.assigns.assoc, id, value)
    socket = assign(socket, assoc: assoc)
    {:noreply, socket}
  end

  @impl true
  def handle_event("update", _params, %Socket{} = socket) do
    if Auth.can_edit(socket.assigns.common.user) do
      handle_update(socket)
    else
      {:noreply, assign(socket, :error, "Permission denied")}
    end
  end

  @impl true
  def handle_event("validate", %{"object" => params}, %Socket{} = socket) do
    if Auth.can_edit(socket.assigns.common.user) do
      handle_validate(socket, params)
    else
      {:noreply, assign(socket, :error, "Permission denied")}
    end
  end

  @impl true
  def handle_event("save", %{"object" => params}, %Socket{} = socket) do
    if Auth.can_edit(socket.assigns.common.user) do
      handle_save(socket, params)
    else
      {:noreply, assign(socket, :error, "Permission denied")}
    end
  end

  @impl true
  def handle_event("cancel", _params, %Socket{} = socket) do
    assigns = [
      error: nil,
      changeset: nil,
      enabled: nil,
      assoc: nil
    ]

    {:noreply, assign(socket, assigns)}
  end

  @spec handle_update(Socket.t()) :: {:noreply, Socket.t()}
  defp handle_update(%Socket{} = socket) do
    type = socket.assigns.request.type
    enabled = MapSet.new()
    obj = struct(type)
    changeset = Updates.get_update_changeset(obj, [])
    changeset = %{changeset | action: :update}

    assigns = [
      error: nil,
      changeset: changeset,
      enabled: enabled,
      assoc: %{}
    ]

    {:noreply, assign(socket, assigns)}
  end

  @spec handle_validate(Socket.t(), map()) :: {:noreply, Socket.t()}
  def handle_validate(%Socket{} = socket, params) do
    assoc = socket.assigns.assoc
    {enabled, _, changeset} = get_update_changeset(socket, params, assoc)

    assigns = [
      enabled: enabled,
      changeset: changeset
    ]

    {:noreply, assign(socket, assigns)}
  end

  @spec handle_save(Socket.t(), map()) :: {:noreply, Socket.t()}
  defp handle_save(%Socket{} = socket, params) do
    type = socket.assigns.request.type
    filter = socket.assigns.request.filter
    query = Query.query(type) |> Query.filter_by_filter(filter)

    {_, updates, changeset} = get_update_changeset(socket, params, socket.assigns.assoc)

    socket =
      case changeset.valid? do
        true ->
          case Updates.apply_updates(updates, query) do
            :ok ->
              PenguinMemoriesWeb.Endpoint.broadcast("refresh", "refresh", %{})
              assign(socket, edit: nil, changeset: nil, error: nil, enabled: nil)

            {:error, reason} ->
              assign(socket, :error, "Error bulk update: #{reason}")
          end

        false ->
          assign(socket, :error, "Form is invalid")
      end

    {:noreply, socket}
  end

  @spec field_to_enable_field_id(Fields.UpdateField.t()) :: atom()
  defp field_to_enable_field_id(%Fields.UpdateField{} = field) do
    String.to_atom(Atom.to_string(field.id) <> "_enable")
  end

  @spec string_to_boolean(String.t()) :: boolean
  defp string_to_boolean("true"), do: true
  defp string_to_boolean(_), do: false

  @spec get_field_value(params :: map(), assoc :: map(), field :: Fields.UpdateField.t()) :: any()
  defp get_field_value(_params, assoc, %Fields.UpdateField{id: id, type: {:single, _}}) do
    Map.get(assoc, id)
  end

  defp get_field_value(_params, assoc, %Fields.UpdateField{id: id, type: {:multiple, _}}) do
    Map.get(assoc, id)
  end

  defp get_field_value(params, _assoc, %Fields.UpdateField{id: id}) do
    Map.get(params, Atom.to_string(id))
  end

  @spec get_update_changes(
          fields :: list(Fields.UpdateField.t()),
          params :: map(),
          assoc :: map()
        ) ::
          {MapSet.t(), list(Updates.UpdateChange.t())}
  def get_update_changes(fields, %{} = params, %{} = assoc) do
    enabled =
      Enum.reduce(fields, MapSet.new(), fn
        %Fields.UpdateField{} = field, enabled ->
          enable_id = Atom.to_string(field_to_enable_field_id(field))
          enable_value = string_to_boolean(Map.get(params, enable_id, "false"))

          if enable_value do
            MapSet.put(enabled, field.id)
          else
            enabled
          end
      end)

    fields = Enum.filter(fields, fn field -> MapSet.member?(enabled, field.id) end)

    updates =
      Enum.reduce(fields, [], fn
        %Fields.UpdateField{} = field, updates ->
          value = get_field_value(params, assoc, field)

          update = %Updates.UpdateChange{
            field_id: field.field_id,
            change: field.change,
            type: field.type,
            value: value
          }

          [update | updates]
      end)

    {enabled, updates}
  end

  @spec get_update_changeset(socket :: Socket.t(), params :: map(), assoc :: map()) ::
          {MapSet.t(), list(Updates.UpdateChange.t()), Changeset.t()}
  defp get_update_changeset(%Socket{} = socket, %{} = params, %{} = assoc) do
    type = socket.assigns.request.type
    fields = Fields.get_update_fields(type, socket.assigns.common.user)

    obj = struct(type)
    {enabled, updates} = get_update_changes(fields, params, assoc)
    changeset = Updates.get_update_changeset(obj, updates)
    {enabled, updates, changeset}
  end

  @spec reload(Socket.t()) :: Socket.t()
  defp reload(%Socket{} = socket) do
    filter = socket.assigns.request.filter
    type = socket.assigns.request.type
    count = Query.count_results(filter, type)
    assign(socket, count: count)
  end
end
