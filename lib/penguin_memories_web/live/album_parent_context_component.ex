defmodule PenguinMemoriesWeb.AlbumParentContextComponent do
  @moduledoc """
  Live component for editing album parent relationships with full context support.
  Allows users to:
  - Add new parent albums
  - Remove existing parent relationships  
  - Edit context information (context_name, context_sort_name, context_cover_photo_id)
  """

  use PenguinMemoriesWeb, :live_component

  alias Ecto.Changeset
  alias PenguinMemories.Database.Query
  alias PenguinMemories.Database.Query.Filter
  alias PenguinMemories.Photos.Album

  @impl true
  def mount(socket) do
    assigns = [
      # Parent selection state
      parent_choices: [],
      parent_search_text: "",
      parent_search_error: nil,
      parent_search_disabled: true,

      # Current parent relationships with context
      current_relationships: []
    ]

    {:ok, assign(socket, assigns)}
  end

  @impl true
  def update(params, socket) do
    form = params.form
    field = params.field
    updates = params.updates
    search = Map.get(params, :search, %{})

    # Get current album parents value from form - check changeset changes first, then original data
    raw_value =
      case Changeset.fetch_change(form.source, field.id) do
        {:ok, changed_value} ->
          changed_value

        :error ->
          Changeset.get_field(form.source, field.id)
      end

    # Convert raw value to relationship data structures
    current_relationships = normalize_relationships(raw_value)

    socket =
      socket
      |> assign(:form, form)
      |> assign(:field, field)
      |> assign(:updates, updates)
      |> assign(:search, search)
      |> assign(:current_relationships, current_relationships)
      |> assign(:parent_search_disabled, false)

    {:ok, socket}
  end

  @impl true
  def handle_event("search_parent", %{"value" => text}, socket) do
    if String.length(text) >= 3 do
      search_for_parents(socket, text)
    else
      socket = assign(socket, parent_choices: [], parent_search_text: text)
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("update_context", params, socket) when is_map(params) do
    # Handle form-style events from phx-change
    # These come with _target to identify which input triggered the change
    case params do
      %{"_target" => _target, "value" => _value} ->
        # Extract parent-id and field from the input's attributes
        # Since we can't easily get these from form events, we'll handle this differently
        # For now, just return without error to prevent crashes
        {:noreply, socket}

      # Handle direct phx-value style events (if they come through this path)
      %{"parent-id" => parent_id_string, "field" => field, "value" => value} ->
        handle_context_update(socket, parent_id_string, field, value)

      _ ->
        {:noreply, socket}
    end
  end

  @impl true
  def handle_event("add_parent", %{"id" => parent_id_string}, socket) do
    parent_id = String.to_integer(parent_id_string)

    # Find the parent info from choices
    parent_choice = Enum.find(socket.assigns.parent_choices, &(&1.id == parent_id))

    if parent_choice do
      # Create new relationship with default context
      new_relationship = %{
        parent_id: parent_id,
        parent_name: parent_choice.name,
        context_name: nil,
        context_sort_name: nil,
        context_cover_photo_id: nil
      }

      # Add to current relationships
      updated_relationships = [new_relationship | socket.assigns.current_relationships]

      socket =
        socket
        |> assign(:current_relationships, updated_relationships)
        |> assign(:parent_choices, [])
        |> assign(:parent_search_text, "")
        |> notify_parent_of_changes(updated_relationships)

      {:noreply, socket}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("remove_parent", %{"parent-id" => parent_id_string}, socket) do
    parent_id = String.to_integer(parent_id_string)

    # Remove the relationship
    updated_relationships =
      Enum.reject(socket.assigns.current_relationships, &(&1.parent_id == parent_id))

    socket =
      socket
      |> assign(:current_relationships, updated_relationships)
      |> notify_parent_of_changes(updated_relationships)

    {:noreply, socket}
  end

  @impl true
  def handle_event(
        "update_context_field",
        %{"parent-id" => parent_id_string, "field" => field, "value" => value},
        socket
      ) do
    handle_context_update(socket, parent_id_string, field, value)
  end

  @impl true
  def handle_event("blur_parent_search", _params, socket) do
    # Clear choices when user clicks away
    socket = assign(socket, parent_choices: [])
    {:noreply, socket}
  end

  # Private helper functions

  defp normalize_relationships(nil), do: []
  defp normalize_relationships([]), do: []

  # credo:disable-for-next-line Credo.Check.Refactor.CyclomaticComplexity
  defp normalize_relationships(relationships) when is_list(relationships) do
    Enum.map(relationships, fn
      # Handle the new format from backend - maps with context data
      %{parent_id: parent_id, parent_name: parent_name} = data when is_integer(parent_id) ->
        %{
          parent_id: parent_id,
          parent_name: parent_name,
          context_name: Map.get(data, :context_name),
          context_sort_name: Map.get(data, :context_sort_name),
          context_cover_photo_id: Map.get(data, :context_cover_photo_id)
        }

      # Handle Album struct (legacy compatibility)
      %Album{id: id, name: name} ->
        %{
          parent_id: id,
          parent_name: name,
          context_name: nil,
          context_sort_name: nil,
          context_cover_photo_id: nil
        }

      # Handle mixed formats that might come from form operations
      data when is_map(data) ->
        parent_id =
          Map.get(data, "parent_id") || Map.get(data, :parent_id) ||
            Map.get(data, "id") || Map.get(data, :id)

        parent_name =
          Map.get(data, "parent_name") || Map.get(data, :parent_name) ||
            Map.get(data, "name") || Map.get(data, :name) || "Unknown"

        %{
          parent_id: parent_id,
          parent_name: parent_name,
          context_name: Map.get(data, "context_name") || Map.get(data, :context_name),
          context_sort_name:
            Map.get(data, "context_sort_name") || Map.get(data, :context_sort_name),
          context_cover_photo_id:
            Map.get(data, "context_cover_photo_id") || Map.get(data, :context_cover_photo_id)
        }
    end)
  end

  defp search_for_parents(socket, text) do
    search = %Filter{query: text}

    # Get currently selected parent IDs to exclude from choices
    selected_ids =
      socket.assigns.current_relationships
      |> Enum.map(& &1.parent_id)
      |> MapSet.new()

    case Query.query_icons(search, 10, Album, "thumb") do
      {:ok, icons} ->
        # Filter out already selected parents
        parent_choices = Enum.reject(icons, fn icon -> MapSet.member?(selected_ids, icon.id) end)

        socket =
          socket
          |> assign(:parent_choices, parent_choices)
          |> assign(:parent_search_text, text)
          |> assign(:parent_search_error, nil)

        {:noreply, socket}

      {:error, reason} ->
        socket =
          socket
          |> assign(:parent_choices, [])
          |> assign(:parent_search_text, text)
          |> assign(:parent_search_error, "Search error: #{reason}")

        {:noreply, socket}
    end
  end

  defp notify_parent_of_changes(socket, relationships) do
    # Convert relationships back to format expected by form
    form_value =
      Enum.map(relationships, fn rel ->
        %{
          parent_id: rel.parent_id,
          parent_name: rel.parent_name,
          context_name: rel.context_name,
          context_sort_name: rel.context_sort_name,
          context_cover_photo_id: rel.context_cover_photo_id
        }
      end)

    # Notify parent LiveView of the change
    send(socket.assigns.updates, {:selected, socket.assigns.field.id, form_value})

    socket
  end

  # credo:disable-for-next-line Credo.Check.Refactor.CyclomaticComplexity
  defp handle_context_update(socket, parent_id_string, field, value) do
    parent_id = String.to_integer(parent_id_string)

    # Update the specific field for this relationship
    updated_relationships =
      Enum.map(socket.assigns.current_relationships, fn rel ->
        if rel.parent_id == parent_id do
          case field do
            "context_name" ->
              %{rel | context_name: if(value == "", do: nil, else: value)}

            "context_sort_name" ->
              %{rel | context_sort_name: if(value == "", do: nil, else: value)}

            "context_cover_photo_id" ->
              case value do
                "" ->
                  %{rel | context_cover_photo_id: nil}

                id_string ->
                  case Integer.parse(id_string) do
                    {id, ""} -> %{rel | context_cover_photo_id: id}
                    # Invalid number, don't change
                    _ -> rel
                  end
              end

            _ ->
              rel
          end
        else
          rel
        end
      end)

    socket =
      socket
      |> assign(:current_relationships, updated_relationships)
      |> notify_parent_of_changes(updated_relationships)

    {:noreply, socket}
  end
end
