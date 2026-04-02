defmodule PenguinMemories.ContextEditingWorkflowTest do
  @moduledoc """
  Test complete context editing workflow to ensure no page reloads occur during
  inline editing of album parent context fields (context_name, context_sort_name, context_cover_photo_id)
  """

  use PenguinMemories.DataCase

  alias PenguinMemories.Database.Query
  alias PenguinMemories.Photos.Album
  alias PenguinMemories.Repo

  describe "context editing workflow" do
    test "edit changeset generation with album_parents_edit associations works correctly" do
      # Create test albums
      {:ok, album} = Repo.insert(%Album{name: "Child Album", sort_name: "child album"})
      {:ok, parent_album} = Repo.insert(%Album{name: "Parent Album", sort_name: "parent album"})

      # Test the core functionality that was causing issues:
      # Creating an edit changeset with context information in associations
      assoc_data = %{
        album_parents_edit: [
          %{
            parent_id: parent_album.id,
            context_name: "Custom Context Name",
            context_sort_name: "Custom Sort Name",
            context_cover_photo_id: nil
          }
        ]
      }

      # This should work without throwing errors (the original bug would cause problems here)
      changeset = Query.get_edit_changeset(album, %{}, assoc_data)

      # Verify the changeset was created successfully
      refute changeset == nil
      assert changeset.valid? == true
      assert changeset.data.__struct__ == Album

      # Verify the album_parents_operations field was populated correctly
      assert Map.has_key?(changeset.changes, :album_parents_operations)

      operations = changeset.changes.album_parents_operations
      assert Map.has_key?(operations, :to_add)
      assert length(operations.to_add) == 1

      added_operation = List.first(operations.to_add)
      assert added_operation.parent_id == parent_album.id
      assert added_operation.context_name == "Custom Context Name"
      assert added_operation.context_sort_name == "Custom Sort Name"
      assert added_operation.context_cover_photo_id == nil
    end

    test "form workflow prevents immediate application during validation" do
      # Create test albums
      {:ok, album} = Repo.insert(%Album{name: "Child Album", sort_name: "child album"})
      {:ok, parent} = Repo.insert(%Album{name: "Parent Album", sort_name: "parent album"})

      # Verify album starts with no parents
      album = Repo.preload(album, :album_parents)
      assert length(album.album_parents) == 0

      # Create form changeset with pending parent addition
      assoc_data = %{
        album_parents_edit: [
          %{
            parent_id: parent.id,
            context_name: "Test Context",
            context_sort_name: nil,
            context_cover_photo_id: nil
          }
        ]
      }

      # Generate changeset (validation step)
      changeset = Query.get_edit_changeset(album, %{}, assoc_data)
      assert changeset.valid? == true

      # CRITICAL TEST: Verify operations are stored but not applied immediately
      # This was the core bug - operations were being applied during validation
      album_reloaded = Repo.get(Album, album.id) |> Repo.preload(:album_parents)
      # Should still be empty!
      assert length(album_reloaded.album_parents) == 0

      # Verify operations are stored in changeset for later application
      operations = changeset.changes.album_parents_operations
      assert length(operations.to_add) == 1
      assert operations.to_add |> List.first() |> Map.get(:parent_id) == parent.id

      # Now apply the changeset (save step)
      {:ok, updated_album} = Query.apply_edit_changeset(changeset)

      # Verify changes are now applied
      final_album = Repo.get(Album, updated_album.id) |> Repo.preload(:album_parents)
      assert length(final_album.album_parents) == 1

      album_parent = List.first(final_album.album_parents)
      assert album_parent.parent_id == parent.id
      assert album_parent.context_name == "Test Context"
    end
  end
end
