defmodule PenguinMemories.ContextBreadcrumbSyncTest do
  @moduledoc """
  Test that updating AlbumParent context information automatically updates
  the breadcrumb data in the AlbumPath table.
  """

  use PenguinMemories.DataCase

  alias PenguinMemories.Database.{PathCompute, Query}
  alias PenguinMemories.Photos.Album
  alias PenguinMemories.Photos.AlbumParent
  alias PenguinMemories.Photos.AlbumPath
  alias PenguinMemories.Repo

  describe "context breadcrumb synchronization" do
    test "updating album parent context_name updates breadcrumb data" do
      # Create a parent-child album hierarchy
      {:ok, parent_album} = Repo.insert(%Album{name: "Parent Album", sort_name: "parent"})
      {:ok, child_album} = Repo.insert(%Album{name: "Child Album", sort_name: "child"})

      # Create the parent relationship with initial context
      {:ok, _album_parent} =
        Repo.insert(%AlbumParent{
          album_id: child_album.id,
          parent_id: parent_album.id,
          context_name: "Original Context Name",
          context_sort_name: "original-sort",
          context_cover_photo_id: nil
        })

      # Trigger path computation (simulating initial indexing)
      # This should populate the AlbumPath table with initial breadcrumb data
      PathCompute.compute_and_store_paths(child_album.id)

      # Verify initial breadcrumb data exists
      initial_path = Repo.get_by(AlbumPath, descendant_id: child_album.id)
      assert initial_path != nil

      # The path_contexts should contain the original context name
      # Check if the original context name appears in the path_contexts map
      initial_contexts = initial_path.path_contexts || %{}

      has_original_context =
        Enum.any?(Map.values(initial_contexts), fn context ->
          context_name =
            case context do
              %{"name" => name} -> name
              name when is_binary(name) -> name
              _ -> ""
            end

          String.contains?(to_string(context_name), "Original Context Name")
        end)

      assert has_original_context, "Initial breadcrumb should contain original context name"

      # Now update the album parent context using the form workflow
      assoc_data = %{
        album_parents_edit: [
          %{
            parent_id: parent_album.id,
            context_name: "UPDATED Context Name",
            context_sort_name: "updated-sort",
            context_cover_photo_id: nil
          }
        ]
      }

      # Apply the update through the proper form workflow
      changeset = Query.get_edit_changeset(child_album, %{}, assoc_data)
      {:ok, _updated_album} = Query.apply_edit_changeset(changeset)

      # Verify the AlbumParent record was updated
      updated_album_parent =
        Repo.get_by(AlbumParent, album_id: child_album.id, parent_id: parent_album.id)

      assert updated_album_parent.context_name == "UPDATED Context Name"
      assert updated_album_parent.context_sort_name == "updated-sort"

      # CRITICAL TEST: Verify the breadcrumb data was also updated
      updated_path = Repo.get_by(AlbumPath, descendant_id: child_album.id)
      assert updated_path != nil

      # The path_contexts should now contain the updated context name
      updated_contexts = updated_path.path_contexts || %{}

      has_updated_context =
        Enum.any?(Map.values(updated_contexts), fn context ->
          context_name =
            case context do
              %{"name" => name} -> name
              name when is_binary(name) -> name
              _ -> ""
            end

          String.contains?(to_string(context_name), "UPDATED Context Name")
        end)

      assert has_updated_context, "Updated breadcrumb should contain new context name"

      # Verify old context name is no longer present
      has_old_context =
        Enum.any?(Map.values(updated_contexts), fn context ->
          context_name =
            case context do
              %{"name" => name} -> name
              name when is_binary(name) -> name
              _ -> ""
            end

          String.contains?(to_string(context_name), "Original Context Name")
        end)

      assert has_updated_context, "Updated breadcrumb should contain new context name"

      # Verify old context name is no longer present
      refute has_old_context, "Updated breadcrumb should not contain old context name"
    end

    test "context updates trigger path recomputation for descendants" do
      # Create a 3-level hierarchy: grandparent -> parent -> child
      {:ok, grandparent} = Repo.insert(%Album{name: "Grandparent", sort_name: "grandparent"})
      {:ok, parent} = Repo.insert(%Album{name: "Parent", sort_name: "parent"})
      {:ok, child} = Repo.insert(%Album{name: "Child", sort_name: "child"})

      # Create relationships
      {:ok, _} =
        Repo.insert(%AlbumParent{
          album_id: parent.id,
          parent_id: grandparent.id,
          context_name: "Parent in Grandparent",
          context_sort_name: nil,
          context_cover_photo_id: nil
        })

      {:ok, _} =
        Repo.insert(%AlbumParent{
          album_id: child.id,
          parent_id: parent.id,
          context_name: "Child in Parent",
          context_sort_name: nil,
          context_cover_photo_id: nil
        })

      # Compute initial paths for all albums
      PathCompute.compute_and_store_paths(grandparent.id)
      PathCompute.compute_and_store_paths(parent.id)
      PathCompute.compute_and_store_paths(child.id)

      # Update the middle level (parent) context
      assoc_data = %{
        album_parents_edit: [
          %{
            parent_id: grandparent.id,
            context_name: "UPDATED Parent in Grandparent",
            context_sort_name: nil,
            context_cover_photo_id: nil
          }
        ]
      }

      # Apply the update
      changeset = Query.get_edit_changeset(parent, %{}, assoc_data)
      {:ok, _} = Query.apply_edit_changeset(changeset)

      # The child's breadcrumb path should reflect the updated parent context
      # because its path goes: Grandparent -> UPDATED Parent in Grandparent -> Child in Parent
      child_path = Repo.get_by(AlbumPath, descendant_id: child.id)
      child_contexts = child_path.path_contexts || %{}

      has_updated_parent_context =
        Enum.any?(Map.values(child_contexts), fn context ->
          context_name =
            case context do
              %{"name" => name} -> name
              name when is_binary(name) -> name
              _ -> ""
            end

          String.contains?(to_string(context_name), "UPDATED Parent in Grandparent")
        end)

      assert has_updated_parent_context,
             "Child's breadcrumb should reflect updated parent context"
    end
  end
end
