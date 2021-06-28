defmodule PenguinMemoriesWeb.ListDetailsLive do
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
  alias PenguinMemories.Database.Types
  alias PenguinMemories.Photos
  alias PenguinMemoriesWeb.FieldHelpers
  alias PenguinMemoriesWeb.LiveRequest
  alias PenguinMemoriesWeb.Router.Helpers, as: Routes

  defmodule Request do
    @moduledoc """
    List of icons to display
    """
    @type selected_type :: PenguinMemoriesWeb.ObjectListLive.selected_type()

    @type t :: %__MODULE__{
            type: Database.object_type()
          }
    @enforce_keys [
      :type
    ]
    defstruct type: nil
  end

  @impl true
  @spec mount(map(), map(), Socket.t()) :: {:ok, Socket.t()}
  def mount(_params, _session, socket) do
    assigns = [
      type: nil,
      error: nil,
      changeset: nil,
      edit_obj: nil,
      assoc: %{},
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

  def handle_event("create", _params, %Socket{} = socket) do
    if Auth.can_edit(socket.assigns.common.user) and socket.assigns.type != Photos.Photo do
      handle_create(socket)
    else
      {:noreply, assign(socket, :error, "Permission denied")}
    end
  end

  @impl true
  def handle_event("validate", %{"object" => params}, %Socket{} = socket) do
    cond do
      not Auth.can_edit(socket.assigns.common.user) ->
        {:noreply, assign(socket, :error, "Permission denied")}

      not is_editing(socket.assigns) ->
        {:noreply, socket}

      true ->
        handle_validate(socket, params)
    end
  end

  @impl true
  def handle_event("save", %{"object" => params}, %Socket{} = socket) do
    cond do
      not Auth.can_edit(socket.assigns.common.user) ->
        {:noreply, assign(socket, :error, "Permission denied")}

      not is_editing(socket.assigns) ->
        {:noreply, socket}

      true ->
        handle_save(socket, params)
    end
  end

  @impl true
  def handle_event("cancel", _params, %Socket{} = socket) do
    assigns = [
      error: nil,
      changeset: nil,
      edit_obj: nil
    ]

    {:noreply, assign(socket, assigns)}
  end

  @impl true
  def handle_event("select-object", %{"id" => id}, socket) do
    id = to_int(id)
    send(socket.parent_pid, {:select_object, id})
    {:noreply, socket}
  end

  @impl true
  def handle_info({:parameters, %LiveRequest{} = common, %Request{} = request}, socket) do
    old = socket.assigns
    request_changed = old.type != request.type

    socket =
      LiveRequest.apply_common(socket, common)
      |> assign(type: request.type)

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

    cond do
      not Auth.can_edit(socket.assigns.common.user) ->
        {:noreply, assign(socket, :error, "Permission denied")}

      not is_editing(socket.assigns) ->
        {:noreply, socket}

      true ->
        handle_validate(socket, socket.assigns.changeset.params)
    end
  end

  @spec is_editing(assigns :: map()) :: boolean()
  defp is_editing(assigns) do
    assigns.changeset != nil
  end

  @spec handle_create(Socket.t()) :: {:noreply, Socket.t()}
  defp handle_create(%Socket{} = socket) do
    type = socket.assigns.type
    changeset = Query.get_edit_changeset(struct(type), %{}, %{})

    assigns = [
      error: nil,
      changeset: changeset,
      edit_object: changeset.data,
      assoc: %{}
    ]

    {:noreply, assign(socket, assigns)}
  end

  @spec handle_validate(Socket.t(), map()) :: {:noreply, Socket.t()}
  def handle_validate(%Socket{} = socket, params) do
    changeset = get_edit_changeset(socket, params)

    assigns = [
      changeset: changeset
    ]

    {:noreply, assign(socket, assigns)}
  end

  @spec handle_save(Socket.t(), map()) :: {:noreply, Socket.t()}
  defp handle_save(%Socket{} = socket, params) do
    changeset = get_edit_changeset(socket, params)

    {socket, assigns} =
      case Query.apply_edit_changeset(changeset) do
        {:error, changeset, error} ->
          assigns = [
            changeset: changeset,
            error: error
          ]

          {socket, assigns}

        {:ok, object} ->
          PenguinMemoriesWeb.Endpoint.broadcast("refresh", "refresh", %{})

          type_name = Types.get_name!(socket.assigns.type)
          url = Routes.main_path(socket, :index, type_name, object.id)
          socket = push_redirect(socket, to: url)

          assigns = [
            mode: :display,
            changeset: nil,
            error: nil
          ]

          {socket, assigns}
      end

    {:noreply, assign(socket, assigns)}
  end

  @spec get_edit_changeset(Socket.t(), map()) :: Changeset.t()
  defp get_edit_changeset(%Socket{} = socket, params) do
    changeset = Query.get_edit_changeset(socket.assigns.edit_object, params, socket.assigns.assoc)
    changeset = %{changeset | action: :insert}

    changeset =
      Enum.reduce(socket.assigns.assoc, changeset, fn {key, value}, changeset ->
        Changeset.put_assoc(changeset, key, value)
      end)

    changeset
  end

  @spec reload(Socket.t()) :: Socket.t()
  def reload(%Socket{} = socket) do
    assigns = [
      error: nil,
      changeset: nil,
      edit_obj: nil
    ]

    assign(socket, assigns)
  end

  @spec to_int(String.t()) :: integer
  defp to_int(int) do
    {int, ""} = Integer.parse(int)
    int
  end
end
