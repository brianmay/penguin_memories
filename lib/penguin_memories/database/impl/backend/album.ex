defmodule PenguinMemories.Database.Impl.Backend.Album do
  @moduledoc """
  Backend Album functions
  """
  alias Ecto.Changeset
  import Ecto.Changeset
  import Ecto.Query

  alias PenguinMemories.Database.Fields.Field
  alias PenguinMemories.Database.Fields.UpdateField
  alias PenguinMemories.Database.Impl.Backend.API
  alias PenguinMemories.Database.Impl.Backend.Private
  alias PenguinMemories.Database.Query
  alias PenguinMemories.Photos.Album
  alias PenguinMemories.Photos.AlbumAscendant
  alias PenguinMemories.Photos.AlbumParent
  alias PenguinMemories.Photos.AlbumUpdate
  alias PenguinMemories.Photos.PhotoAlbum
  alias PenguinMemories.Repo

  @behaviour API

  @impl API
  @spec get_single_name :: String.t()
  def get_single_name, do: "album"

  @impl API
  @spec get_plural_name :: String.t()
  def get_plural_name, do: "albums"

  @impl API
  @spec get_cursor_fields :: list(atom())
  def get_cursor_fields, do: [:sort_name, :name, :id]

  @impl API
  @spec get_parent_fields :: list(atom())
  def get_parent_fields, do: [:parent, :album_parents, :parents]

  @impl API
  @spec get_parent_id_fields :: list(atom())
  def get_parent_id_fields, do: [:parent_id]

  @impl API
  @spec get_index_type :: module() | nil
  def get_index_type, do: AlbumAscendant

  @impl API
  @spec query :: Ecto.Query.t()
  def query do
    photo_count_query =
      from pa in PhotoAlbum,
        join: aa in AlbumAscendant,
        on: aa.descendant_id == pa.album_id and aa.position >= 0,
        group_by: aa.ascendant_id,
        select: %{album_id: aa.ascendant_id, count: count(pa.photo_id, :distinct)}

    child_count_query =
      from a in Album,
        left_join: ap in AlbumParent,
        on: ap.album_id == a.id,
        where: not is_nil(a.parent_id) or not is_nil(ap.parent_id),
        group_by: coalesce(ap.parent_id, a.parent_id),
        select: %{album_id: coalesce(ap.parent_id, a.parent_id), count: count(a.id, :distinct)}

    from o in Album,
      as: :object,
      left_join: pc in subquery(photo_count_query),
      on: pc.album_id == o.id,
      left_join: cc in subquery(child_count_query),
      on: cc.album_id == o.id,
      select: %{
        sort_name: o.sort_name,
        name: o.name,
        id: o.id,
        photo_count: pc.count,
        child_count: cc.count
      },
      order_by: [asc: o.sort_name, asc: o.name, asc: o.id]
  end

  @impl API
  @spec filter_by_photo_id(query :: Ecto.Query.t(), photo_id :: integer) :: Ecto.Query.t()
  def filter_by_photo_id(%Ecto.Query{} = query, photo_id) do
    from [object: o] in query,
      join: op in PhotoAlbum,
      on: op.album_id == o.id,
      where: op.photo_id == ^photo_id
  end

  @impl API
  @spec filter_by_parent_id(query :: Ecto.Query.t(), parent_id :: integer) :: Ecto.Query.t()
  def filter_by_parent_id(%Ecto.Query{} = query, parent_id) do
    # Support both old parent_id field AND new many-to-many AlbumParent relationships
    from [object: o] in query,
      left_join: ap in AlbumParent,
      on: ap.album_id == o.id,
      where: o.parent_id == ^parent_id or ap.parent_id == ^parent_id,
      # Update select to include context fields when available
      select_merge: %{
        context_name: ap.context_name,
        context_sort_name: ap.context_sort_name,
        context_cover_photo_id: ap.context_cover_photo_id
      }
  end

  @impl API
  @spec filter_by_reference(
          query :: Ecto.Query.t(),
          reference :: {module(), integer()},
          deep :: boolean()
        ) ::
          Ecto.Query.t()
  def filter_by_reference(%Ecto.Query{} = query, {Album, id}, _deep) do
    filter_by_parent_id(query, id)
  end

  def filter_by_reference(%Ecto.Query{} = query, _, _deep) do
    query
  end

  @impl API
  @spec preload_details(query :: Ecto.Query.t()) :: Ecto.Query.t()
  def preload_details(query) do
    preload(query, [
      :cover_photo,
      :parent,
      :children,
      [album_parents: :parent],
      :album_children
    ])
  end

  @impl API
  @spec preload_details_from_results(results :: list(struct())) :: list(struct())
  def preload_details_from_results(results) do
    Repo.preload(results, [
      :cover_photo,
      :parent,
      :children,
      [album_parents: :parent],
      :album_children
    ])
  end

  @impl API
  @spec get_title_from_result(result :: map()) :: String.t()
  def get_title_from_result(%{} = result) do
    # Use context_name if available, otherwise fall back to name
    result[:context_name] || result.name || "Untitled"
  end

  @impl API
  @spec get_subtitle_from_result(result :: map()) :: String.t() | nil
  def get_subtitle_from_result(%{} = result) do
    # Use context_sort_name if available, otherwise fall back to sort_name
    result[:context_sort_name] || result.sort_name
  end

  @impl API
  @spec get_icon_details_from_result(result :: map()) :: String.t() | nil
  def get_icon_details_from_result(%{} = result) do
    photo_count = result.photo_count || 0
    child_count = result.child_count || 0
    "#{photo_count} photos, #{child_count} albums"
  end

  @impl API
  @spec get_details_from_result(
          result :: map(),
          icon_size :: String.t(),
          video_size :: String.t()
        ) :: Query.Details.t()
  def get_details_from_result(%{} = result, _icon_size, _video_size) do
    icon = Query.get_icon_from_result(result, Album)
    orig = Query.get_orig_from_result(result, Album)
    raw = Query.get_raw_from_result(result, Album)
    cursor = Paginator.cursor_for_record(result, get_cursor_fields())

    obj = %Album{
      result.o
      | photo_count: result.photo_count || 0,
        child_count: result.child_count || 0
    }

    %Query.Details{
      obj: obj,
      icon: icon,
      orig: orig,
      raw: raw,
      videos: [],
      cursor: cursor,
      type: Album
    }
  end

  @impl API
  @spec get_fields :: list(Field.t())
  def get_fields do
    [
      %Field{
        id: :id,
        name: "ID",
        type: :integer,
        read_only: true,
        searchable: true
      },
      %Field{
        id: :name,
        name: "Name",
        type: :string,
        searchable: true
      },
      %Field{
        id: :sort_name,
        name: "Sort Name",
        type: :string,
        searchable: true
      },
      %Field{
        id: :parent,
        name: "Parent",
        type: {:single, Album},
        searchable: true
      },
      %Field{
        id: :album_parents,
        name: "Album Parents",
        type: {:multiple, AlbumParent},
        searchable: true,
        read_only: true
      },
      %Field{
        id: :album_parents_edit,
        name: "Album Parents",
        type: {:multiple, Album},
        searchable: true
      },
      %Field{
        id: :photo_count,
        name: "Photo Count",
        type: :integer,
        read_only: true
      },
      %Field{
        id: :child_count,
        name: "Child Albums",
        type: :integer,
        read_only: true
      },
      %Field{
        id: :description,
        name: "Description",
        type: :markdown
      },
      %Field{
        id: :private_notes,
        name: "Private Notes",
        type: :markdown,
        access: :private
      },
      %Field{
        id: :cover_photo,
        name: "Cover Photo",
        type: {:single, PenguinMemories.Photos.Photo},
        searchable: true
      },
      %Field{
        id: :reindex,
        name: "Re-index",
        type: :boolean,
        searchable: true
      },
      %Field{
        id: :revised,
        name: "Revised time",
        type: :datetime,
        searchable: true
      }
    ]
  end

  @impl API
  @spec get_update_fields :: list(UpdateField.t())
  def get_update_fields do
    [
      %UpdateField{
        id: :parent,
        field_id: :parent,
        name: "Parent",
        type: {:single, Album},
        change: :set
      },
      %UpdateField{
        id: :album_parents_edit,
        field_id: :album_parents_edit,
        name: "Parents with Context",
        type: {:multiple, Album},
        change: :set
      },
      %UpdateField{
        id: :revised,
        field_id: :revised,
        name: "Revised time",
        type: :datetime,
        change: :set
      }
    ]
  end

  @impl API
  @spec edit_changeset(object :: Album.t(), attrs :: map(), assoc :: map()) :: Changeset.t()
  def edit_changeset(%Album{} = object, attrs, assoc) do
    # Filter out Phoenix form dummy fields that cause issues with change()
    cleaned_attrs =
      attrs
      |> Enum.reject(fn {key, _value} ->
        is_binary(key) and String.starts_with?(key, "_unused_")
      end)
      |> Enum.into(%{})

    # Handle new objects that don't exist in database yet
    if is_nil(object.id) do
      object
      |> Map.put(:album_parents, [])
      |> cast(cleaned_attrs, [
        :cover_photo_id,
        :name,
        :sort_name,
        :description,
        :private_notes,
        :reindex,
        :revised
      ])
      |> validate_required([:sort_name, :name])
      |> handle_album_parents_assoc(assoc)
      |> Private.put_all_assoc(assoc, [:parent, :cover_photo])
    else
      # Existing object - handle normally with preloading
      edit_changeset_existing(object, cleaned_attrs, assoc)
    end
  end

  @spec edit_changeset_existing(object :: Album.t(), attrs :: map(), assoc :: map()) ::
          Changeset.t()
  defp edit_changeset_existing(%Album{} = object, attrs, assoc) do
    # Always preload album_parents for the edit changeset UI
    preloaded_object =
      if Ecto.assoc_loaded?(object.album_parents) do
        # Also need to check if parent associations are loaded
        needs_parent_preload =
          object.album_parents
          |> Enum.any?(fn album_parent -> !Ecto.assoc_loaded?(album_parent.parent) end)

        if needs_parent_preload do
          Repo.preload(object, album_parents: :parent)
        else
          object
        end
      else
        Repo.preload(object, album_parents: :parent)
      end

    # Convert AlbumParent objects to Album objects for the UI form field
    # The AlbumParentContextComponent expects relationship maps with context data
    parent_relationships =
      preloaded_object.album_parents
      |> Enum.map(fn album_parent ->
        %{
          parent_id: album_parent.parent_id,
          parent_name: album_parent.parent.name,
          context_name: album_parent.context_name,
          context_sort_name: album_parent.context_sort_name,
          context_cover_photo_id: album_parent.context_cover_photo_id
        }
      end)

    # Put the relationship data (with context) in the album_parents_edit field for the form
    # Keep the original album_parents for display
    object_with_ui_parents = %{preloaded_object | album_parents_edit: parent_relationships}

    object_with_ui_parents
    |> cast(attrs, [
      :name,
      :sort_name,
      :description,
      :private_notes,
      :reindex,
      :revised
    ])
    |> validate_required([:sort_name, :name])
    |> handle_album_parents_assoc(assoc)
    |> Private.put_all_assoc(assoc, [:parent, :cover_photo])
  end

  @spec handle_album_parents_assoc(changeset :: Changeset.t(), assoc :: map()) :: Changeset.t()
  defp handle_album_parents_assoc(changeset, assoc) do
    case Map.fetch(assoc, :album_parents_edit) do
      {:ok, new_album_parents} ->
        # Preload album_parents if not already loaded
        album =
          if Ecto.assoc_loaded?(changeset.data.album_parents) do
            changeset.data
          else
            Repo.preload(changeset.data, :album_parents)
          end

        updated_changeset = %{changeset | data: album}
        apply_album_parents_changes(updated_changeset, new_album_parents)

      :error ->
        changeset
    end
  end

  @spec apply_album_parents_changes(changeset :: Changeset.t(), new_album_parents :: list()) ::
          Changeset.t()
  defp apply_album_parents_changes(changeset, new_album_parents) do
    album = changeset.data

    # Handle new album creation differently from existing album updates
    if is_nil(album.id) do
      # For new albums, we can't validate circular references yet (no ID to check against)
      # Just store the parent data for processing after the album is created
      new_relationships = extract_album_parent_data(new_album_parents)

      changeset
      |> Ecto.Changeset.put_change(:album_parents_operations, %{
        to_add: new_relationships,
        to_update: [],
        to_remove: []
      })
      |> Ecto.Changeset.put_change(:album_parents_edit, new_album_parents)
    else
      current_album_parents = album.album_parents || []

      # Convert new_album_parents to a format we can work with
      # Each item should be an Album struct or map with id
      new_relationships = extract_album_parent_data(new_album_parents)
      current_relationships = extract_current_album_parent_data(current_album_parents)

      # Calculate operations needed
      {to_add, to_update, to_remove} =
        calculate_album_parent_operations(current_relationships, new_relationships)

      # VALIDATION ONLY: Check for circular references but DON'T apply changes
      # This is proper form behavior - validate without side effects
      case validate_no_circular_references(album.id, to_add) do
        :ok ->
          # Store the operations in changeset for later application during save
          # DO NOT apply them to the database during validation
          changeset
          |> Ecto.Changeset.put_change(:album_parents_operations, %{
            to_add: to_add,
            to_update: to_update,
            to_remove: to_remove
          })
          |> Ecto.Changeset.put_change(:album_parents_edit, new_album_parents)

        {:error, :circular_reference} ->
          Ecto.Changeset.add_error(
            changeset,
            :album_parents_edit,
            "Cannot add parent relationships that would create circular references"
          )
      end
    end
  end

  @spec extract_album_parent_data(list()) :: list(map())
  defp extract_album_parent_data(albums_or_data) do
    result =
      Enum.map(albums_or_data, fn
        # Handle Album struct (from UI selection)
        %Album{id: parent_id} ->
          %{
            parent_id: parent_id,
            # Default context, will use album name
            context_name: nil,
            # Default context, will use album sort_name
            context_sort_name: nil,
            context_cover_photo_id: nil
          }

        # Handle AlbumParent struct (existing relationships)
        %AlbumParent{} = ap ->
          %{
            parent_id: ap.parent_id,
            context_name: ap.context_name,
            context_sort_name: ap.context_sort_name,
            context_cover_photo_id: ap.context_cover_photo_id
          }

        # Handle map with parent_id directly (atom keys)
        %{parent_id: parent_id} = data when is_integer(parent_id) ->
          %{
            parent_id: parent_id,
            context_name: data[:context_name],
            context_sort_name: data[:context_sort_name],
            context_cover_photo_id: data[:context_cover_photo_id]
          }

        # Handle case where parent is provided instead of parent_id
        %{parent: %{id: parent_id}} = data ->
          %{
            parent_id: parent_id,
            context_name: data[:context_name],
            context_sort_name: data[:context_sort_name],
            context_cover_photo_id: data[:context_cover_photo_id]
          }

        # Handle map with id field (Album-like object)
        %{id: parent_id} when is_integer(parent_id) ->
          %{
            parent_id: parent_id,
            context_name: nil,
            context_sort_name: nil,
            context_cover_photo_id: nil
          }

        # Handle map with string keys (from bulk update forms)
        %{"parent_id" => parent_id} = data when is_integer(parent_id) ->
          %{
            parent_id: parent_id,
            context_name: data["context_name"],
            context_sort_name: data["context_sort_name"],
            context_cover_photo_id: data["context_cover_photo_id"]
          }

        # Skip any items that don't match expected patterns
        _ ->
          nil
      end)

    # Remove nil entries
    Enum.filter(result, & &1)
  end

  @spec extract_current_album_parent_data(list()) :: list(map())
  defp extract_current_album_parent_data(current_album_parents) do
    Enum.map(current_album_parents, fn ap ->
      %{
        parent_id: ap.parent_id,
        context_name: ap.context_name,
        context_sort_name: ap.context_sort_name,
        context_cover_photo_id: ap.context_cover_photo_id
      }
    end)
  end

  @spec calculate_album_parent_operations(list(map()), list(map())) ::
          {list(map()), list(map()), list(integer())}
  defp calculate_album_parent_operations(current_relationships, new_relationships) do
    current_parent_ids = MapSet.new(current_relationships, & &1.parent_id)
    new_parent_ids = MapSet.new(new_relationships, & &1.parent_id)

    # Relationships to remove (in current but not in new)
    to_remove = MapSet.difference(current_parent_ids, new_parent_ids) |> MapSet.to_list()

    # Relationships to add (in new but not in current)
    to_add_parent_ids = MapSet.difference(new_parent_ids, current_parent_ids)
    to_add = Enum.filter(new_relationships, fn rel -> rel.parent_id in to_add_parent_ids end)

    # Relationships to potentially update (in both current and new)
    to_check_parent_ids = MapSet.intersection(current_parent_ids, new_parent_ids)

    to_update =
      Enum.filter(new_relationships, fn new_rel ->
        if new_rel.parent_id in to_check_parent_ids do
          # Find corresponding current relationship and check if context changed
          current_rel = Enum.find(current_relationships, &(&1.parent_id == new_rel.parent_id))
          context_changed?(current_rel, new_rel)
        else
          false
        end
      end)

    {to_add, to_update, to_remove}
  end

  @spec context_changed?(map(), map()) :: boolean()
  defp context_changed?(current, new) do
    current.context_name != new.context_name or
      current.context_sort_name != new.context_sort_name or
      current.context_cover_photo_id != new.context_cover_photo_id
  end

  @spec validate_no_circular_references(album_id :: integer(), to_add :: list(map())) ::
          :ok | {:error, :circular_reference}
  defp validate_no_circular_references(album_id, to_add) do
    # Check each parent we're trying to add for circular references
    circular_refs =
      Enum.filter(to_add, fn rel_data ->
        parent_id = rel_data.parent_id
        # Check if adding this parent would create a cycle:
        # 1. album_id == parent_id (self-reference)  
        # 2. parent_id is already an ancestor of album_id (would create redundant path or cycle)
        album_id == parent_id or is_ancestor?(parent_id, album_id)
      end)

    if Enum.empty?(circular_refs) do
      :ok
    else
      {:error, :circular_reference}
    end
  end

  @spec apply_album_parent_operations(
          album_id :: integer(),
          to_add :: list(map()),
          to_update :: list(map()),
          to_remove :: list(integer())
        ) :: :ok | {:error, any()}
  def apply_album_parent_operations(album_id, to_add, to_update, to_remove) do
    try do
      # Remove relationships
      Enum.each(to_remove, fn parent_id ->
        case remove_from_parent(album_id, parent_id) do
          {:ok, _} -> :ok
          # Already removed, ignore
          {:error, :not_found} -> :ok
          {:error, reason} -> throw({:remove_error, reason})
        end
      end)

      # Add new relationships
      Enum.each(to_add, fn rel_data ->
        context_attrs = %{
          context_name: rel_data.context_name,
          context_sort_name: rel_data.context_sort_name,
          context_cover_photo_id: rel_data.context_cover_photo_id
        }

        case add_to_parent(album_id, rel_data.parent_id, context_attrs) do
          {:ok, _} -> :ok
          {:error, :circular_reference} -> throw({:add_error, :circular_reference})
          {:error, changeset} -> throw({:add_error, changeset})
        end
      end)

      # Update existing relationships
      Enum.each(to_update, fn rel_data ->
        context_attrs = %{
          context_name: rel_data.context_name,
          context_sort_name: rel_data.context_sort_name,
          context_cover_photo_id: rel_data.context_cover_photo_id
        }

        case update_context(album_id, rel_data.parent_id, context_attrs) do
          {:ok, _} ->
            :ok

          {:error, :not_found} ->
            # Relationship was removed, try adding it
            case add_to_parent(album_id, rel_data.parent_id, context_attrs) do
              {:ok, _} -> :ok
              {:error, reason} -> throw({:update_add_error, reason})
            end

          {:error, changeset} ->
            throw({:update_error, changeset})
        end
      end)

      :ok
    catch
      {error_type, reason} -> {:error, {error_type, reason}}
    end
  end

  @impl API
  @spec update_changeset(
          attrs :: map(),
          assoc :: map(),
          enabled :: MapSet.t()
        ) ::
          Changeset.t()
  def update_changeset(attrs, assoc, enabled) do
    changeset =
      %AlbumUpdate{parent: nil, album_parents_edit: nil}
      |> Private.selective_cast(attrs, enabled, [:revised])
      |> Private.selective_put_assoc(assoc, enabled, [:parent])

    # Handle album_parents_edit separately since it's not a real association in AlbumUpdate
    # Auto-enable the field if assoc data is present (UX improvement)
    should_update_album_parents =
      MapSet.member?(enabled, :album_parents_edit) or
        (Map.has_key?(assoc, :album_parents_edit) and not is_nil(assoc.album_parents_edit))

    if should_update_album_parents do
      case Map.fetch(assoc, :album_parents_edit) do
        {:ok, value} ->
          Ecto.Changeset.put_change(changeset, :album_parents_edit, value)

        :error ->
          changeset
      end
    else
      changeset
    end
  end

  # Context-aware album functions for many-to-many parent relationships

  @doc """
  Add an album to a parent with optional context-specific presentation.
  Validates that this won't create a circular reference.
  """
  @spec add_to_parent(integer(), integer(), map()) ::
          {:ok, AlbumParent.t()} | {:error, Changeset.t() | :circular_reference}
  def add_to_parent(album_id, parent_id, context_attrs \\ %{}) do
    # Prevent circular references - check if parent_id is already a descendant of album_id
    if album_id == parent_id or is_ancestor?(album_id, parent_id) do
      {:error, :circular_reference}
    else
      default_attrs = %{
        album_id: album_id,
        parent_id: parent_id
      }

      attrs =
        default_attrs
        |> Map.merge(context_attrs)
        |> maybe_set_default_sort_name(album_id)

      result =
        %AlbumParent{}
        |> AlbumParent.changeset(attrs)
        |> Repo.insert()

      case result do
        {:ok, album_parent} ->
          # Mark both albums for reindexing to update the AlbumAscendant table
          mark_for_reindex(album_id)
          mark_for_reindex(parent_id)
          {:ok, album_parent}

        {:error, changeset} ->
          {:error, changeset}
      end
    end
  end

  @doc """
  Remove an album from a parent.
  """
  @spec remove_from_parent(integer(), integer()) :: {:ok, AlbumParent.t()} | {:error, :not_found}
  def remove_from_parent(album_id, parent_id) do
    case Repo.get_by(AlbumParent, album_id: album_id, parent_id: parent_id) do
      nil ->
        {:error, :not_found}

      album_parent ->
        result = Repo.delete(album_parent)
        # Mark both albums for reindexing to update the AlbumAscendant table
        mark_for_reindex(album_id)
        mark_for_reindex(parent_id)
        result
    end
  end

  @doc """
  Get an album with context-specific presentation from a specific parent.
  Returns the album with virtual fields for context name, sort name, and cover photo.
  """
  @spec get_album_in_context(integer(), integer()) :: {:ok, Album.t()} | {:error, :not_found}
  def get_album_in_context(album_id, parent_id) do
    query =
      from(a in Album,
        left_join: ap in AlbumParent,
        on: ap.album_id == a.id and ap.parent_id == ^parent_id,
        where: a.id == ^album_id,
        select: %{
          a
          | context_name: coalesce(ap.context_name, a.name),
            context_sort_name: coalesce(ap.context_sort_name, coalesce(a.sort_name, a.name)),
            context_cover_photo_id: coalesce(ap.context_cover_photo_id, a.cover_photo_id)
        }
      )

    case Repo.one(query) do
      nil -> {:error, :not_found}
      album -> {:ok, album}
    end
  end

  @doc """
  Get all children of a parent album, sorted by context-specific sort names.
  Returns albums with context-specific presentation.
  """
  @spec get_children_in_context(integer()) :: [Album.t()]
  def get_children_in_context(parent_id) do
    from(a in Album,
      join: ap in AlbumParent,
      on: ap.album_id == a.id,
      where: ap.parent_id == ^parent_id,
      order_by: coalesce(ap.context_sort_name, coalesce(a.sort_name, a.name)),
      select: %{
        a
        | context_name: coalesce(ap.context_name, a.name),
          context_sort_name: coalesce(ap.context_sort_name, coalesce(a.sort_name, a.name)),
          context_cover_photo_id: coalesce(ap.context_cover_photo_id, a.cover_photo_id)
      }
    )
    |> Repo.all()
  end

  @doc """
  Get all parents of an album.
  """
  @spec get_parents(integer()) :: [Album.t()]
  def get_parents(album_id) do
    from(a in Album,
      join: ap in AlbumParent,
      on: ap.parent_id == a.id,
      where: ap.album_id == ^album_id
    )
    |> Repo.all()
  end

  @doc """
  Update context-specific presentation for an album-parent relationship.
  """
  @spec update_context(integer(), integer(), map()) ::
          {:ok, AlbumParent.t()} | {:error, Changeset.t() | :not_found}
  def update_context(album_id, parent_id, context_attrs) do
    case Repo.get_by(AlbumParent, album_id: album_id, parent_id: parent_id) do
      nil ->
        {:error, :not_found}

      album_parent ->
        album_parent
        |> AlbumParent.changeset(context_attrs)
        |> Repo.update()
    end
  end

  # Helper function to set default context_sort_name if not provided
  @spec maybe_set_default_sort_name(map(), integer()) :: map()
  defp maybe_set_default_sort_name(attrs, album_id) do
    if Map.has_key?(attrs, :context_sort_name) do
      attrs
    else
      case Repo.get(Album, album_id) do
        nil ->
          attrs

        album ->
          default_sort_name = album.sort_name || album.name || "Unknown"
          Map.put(attrs, :context_sort_name, default_sort_name)
      end
    end
  end

  @doc """
  Get all ancestor albums for a given album through all possible parent paths.
  Returns a list of albums that are ancestors through any path.
  """
  @spec get_all_ancestors(integer()) :: [Album.t()]
  def get_all_ancestors(album_id) do
    from(a in Album,
      join: aa in AlbumAscendant,
      on: aa.ascendant_id == a.id,
      where: aa.descendant_id == ^album_id and aa.position > 0,
      distinct: a.id,
      order_by: [aa.position, a.name]
    )
    |> Repo.all()
  end

  @doc """
  Get all descendant albums for a given album through all possible child paths.
  Returns a list of albums that are descendants through any path.
  """
  @spec get_all_descendants(integer()) :: [Album.t()]
  def get_all_descendants(album_id) do
    from(a in Album,
      join: aa in AlbumAscendant,
      on: aa.descendant_id == a.id,
      where: aa.ascendant_id == ^album_id and aa.position < 0,
      distinct: a.id,
      order_by: [desc: aa.position, asc: a.name]
    )
    |> Repo.all()
  end

  @doc """
  Check if one album is an ancestor of another through any path.
  This checks both the indexed AlbumAscendant table AND current parent relationships
  to handle cases where the index hasn't been updated yet.
  """
  @spec is_ancestor?(integer(), integer()) :: boolean()
  def is_ancestor?(ancestor_id, descendant_id) do
    # Check the AlbumAscendant index
    ascendant_exists =
      from(aa in AlbumAscendant,
        where:
          aa.ascendant_id == ^ancestor_id and aa.descendant_id == ^descendant_id and
            aa.position > 0
      )
      |> Repo.exists?()

    if ascendant_exists do
      true
    else
      # Also check current parent relationships that might not be indexed yet
      check_ancestor_via_parents(ancestor_id, descendant_id, MapSet.new())
    end
  end

  # Recursive helper to check ancestry through current parent relationships
  @spec check_ancestor_via_parents(integer(), integer(), MapSet.t()) :: boolean()
  defp check_ancestor_via_parents(ancestor_id, current_id, visited) do
    if MapSet.member?(visited, current_id) do
      # Avoid infinite loops
      false
    else
      visited = MapSet.put(visited, current_id)

      # Get all current parents of current_id
      parent_ids = get_current_parent_ids(current_id)

      # Check if ancestor_id is a direct parent
      if ancestor_id in parent_ids do
        true
      else
        # Recursively check each parent
        Enum.any?(parent_ids, fn parent_id ->
          check_ancestor_via_parents(ancestor_id, parent_id, visited)
        end)
      end
    end
  end

  # Helper to get current parent IDs from both old and new parent relationships
  @spec get_current_parent_ids(integer()) :: [integer()]
  defp get_current_parent_ids(album_id) do
    album = Repo.get!(Album, album_id)

    # Get old-style parent
    old_parent_ids = if album.parent_id, do: [album.parent_id], else: []

    # Get new many-to-many parents
    new_parent_ids =
      from(ap in AlbumParent,
        where: ap.album_id == ^album_id,
        select: ap.parent_id
      )
      |> Repo.all()

    # Combine and deduplicate
    (old_parent_ids ++ new_parent_ids)
    |> Enum.uniq()
  end

  # Helper function to mark an album for reindexing
  @spec mark_for_reindex(integer()) :: :ok
  defp mark_for_reindex(album_id) do
    from(a in Album, where: a.id == ^album_id)
    |> Repo.update_all(set: [reindex: true])

    :ok
  end
end
