defmodule PenguinMemories.Database.PathCompute do
  @moduledoc """
  Computes and maintains complete hierarchical paths for albums to support multiple breadcrumb trails.

  This module is responsible for:
  1. Computing all possible paths from root albums to descendant albums
  2. Maintaining the pm_album_path table
  3. Including context information from AlbumParent relationships
  """

  import Ecto.Query

  alias PenguinMemories.Database.Impl.Index.AlbumAware
  alias PenguinMemories.Photos.{Album, AlbumParent, AlbumPath}
  alias PenguinMemories.Repo

  @spec compute_and_store_paths(integer()) :: :ok
  def compute_and_store_paths(album_id) when is_integer(album_id) do
    # Check if album exists before computing paths
    case Repo.get(Album, album_id) do
      nil ->
        # Album doesn't exist, skip path computation
        :ok

      _album ->
        # Compute all paths from roots to this album
        paths = compute_all_paths_to_album(album_id)

        # Store the paths in the database
        :ok = store_paths(album_id, paths)
    end
  end

  @doc """
  Computes all possible hierarchical paths from root albums down to the target album.

  Returns a list of paths, where each path is:
  - path_ids: [root_id, intermediate_id, ..., target_id]  
  - context_data: map of album_id -> context information for display

  ## Examples

      iex> compute_all_paths_to_album(123)
      [
        %{path_ids: [1, 5, 123], context_data: %{5 => "Memorial Services", 123 => "Uncle Peter's Memorial"}},
        %{path_ids: [2, 6, 123], context_data: %{6 => "Great Ocean Road", 123 => "Uncle Peter's Memorial"}}
      ]
  """
  @spec compute_all_paths_to_album(integer()) :: [%{path_ids: [integer()], context_data: map()}]
  def compute_all_paths_to_album(album_id) do
    # Use recursive algorithm to find all paths from roots to target
    find_all_paths_to_target(album_id, [], MapSet.new())
  end

  @spec find_all_paths_to_target(integer(), [integer()], MapSet.t()) :: [
          %{path_ids: [integer()], context_data: map()}
        ]
  defp find_all_paths_to_target(current_id, path_so_far, visited) do
    # Prevent cycles
    if MapSet.member?(visited, current_id) do
      []
    else
      visited = MapSet.put(visited, current_id)
      current_path = [current_id | path_so_far]

      # Get all parents of current album (both old parent_id and new AlbumParent relationships)
      parent_info = get_album_parents_with_context(current_id)

      case parent_info do
        [] ->
          # This is a root album, return the complete path
          # Don't reverse - path is already root-to-descendant
          path_ids = current_path
          context_data = build_context_data_for_path(path_ids)
          [%{path_ids: path_ids, context_data: context_data}]

        parents ->
          # Recursively find paths through each parent
          parents
          |> Enum.flat_map(fn {parent_id, parent_context} ->
            find_all_paths_to_target(parent_id, current_path, visited)
            |> Enum.map(fn path_info ->
              # Merge context information for the current album based on the parent relationship
              updated_context =
                merge_context_for_album(path_info.context_data, current_id, [
                  {parent_id, parent_context}
                ])

              %{path_info | context_data: updated_context}
            end)
          end)
      end
    end
  end

  @spec get_album_parents_with_context(integer()) :: [{integer(), map()}]
  defp get_album_parents_with_context(album_id) do
    # Get parents from both old parent_id field and new AlbumParent many-to-many relationships
    old_parent_query =
      from a in Album,
        where: a.id == ^album_id and not is_nil(a.parent_id),
        select: %{parent_id: a.parent_id, context: %{}}

    many_to_many_query =
      from ap in AlbumParent,
        where: ap.album_id == ^album_id,
        select: %{
          parent_id: ap.parent_id,
          context: %{
            name: ap.context_name,
            sort_name: ap.context_sort_name
          }
        }

    old_parents = Repo.all(old_parent_query)
    many_to_many_parents = Repo.all(many_to_many_query)

    (old_parents ++ many_to_many_parents)
    |> Enum.map(fn %{parent_id: parent_id, context: context} ->
      {parent_id, context}
    end)
  end

  @spec build_context_data_for_path([integer()]) :: map()
  defp build_context_data_for_path(path_ids) do
    # For each album in the path, get its context-aware display information
    album_map =
      from(a in Album, where: a.id in ^path_ids, select: %{id: a.id, name: a.name})
      |> Repo.all()
      |> Enum.into(%{}, fn %{id: id, name: name} -> {to_string(id), %{name: name}} end)

    album_map
  end

  @spec merge_context_for_album(map(), integer(), [{integer(), map()}]) :: map()
  defp merge_context_for_album(context_data, album_id, parent_info) do
    # Find context information for this album based on its parent relationships
    album_context =
      parent_info
      |> Enum.find_value(%{}, fn {_parent_id, context} ->
        if context[:name], do: context, else: nil
      end)

    if album_context != %{} do
      Map.put(context_data, to_string(album_id), album_context)
    else
      context_data
    end
  end

  @spec store_paths(integer(), [%{path_ids: [integer()], context_data: map()}]) :: :ok
  defp store_paths(album_id, paths) do
    # Delete existing paths for this album
    Repo.delete_all(from ap in AlbumPath, where: ap.descendant_id == ^album_id)

    # Deduplicate paths by path_ids to prevent unique constraint violations
    unique_paths =
      paths
      |> Enum.group_by(& &1.path_ids)
      |> Enum.map(fn {path_ids, path_group} ->
        # If multiple paths have the same path_ids, merge their context data
        merged_context_data =
          path_group
          |> Enum.reduce(%{}, fn %{context_data: context}, acc ->
            Map.merge(acc, context)
          end)

        %{path_ids: path_ids, context_data: merged_context_data}
      end)

    # Insert new paths
    unique_paths
    |> Enum.each(fn %{path_ids: path_ids, context_data: context_data} ->
      changeset =
        AlbumPath.new_path(album_id, path_ids, context_data)

      case Repo.insert(changeset) do
        {:ok, _} ->
          :ok

        {:error, changeset} ->
          # Log error but continue with other paths
          IO.warn("Failed to store path for album #{album_id}: #{inspect(changeset.errors)}")
      end
    end)

    :ok
  end

  @doc """
  Called when an album's parent relationships change.
  Triggers recomputation of paths for this album and all its descendants.
  """
  @spec recompute_paths_for_album_and_descendants(integer()) :: :ok
  def recompute_paths_for_album_and_descendants(album_id) do
    # Get all descendant albums that might be affected
    descendant_ids = AlbumAware.get_child_ids(album_id, Album)

    # Recompute paths for the album itself and all its descendants
    ([album_id] ++ descendant_ids)
    |> Enum.each(&compute_and_store_paths/1)

    :ok
  end
end
