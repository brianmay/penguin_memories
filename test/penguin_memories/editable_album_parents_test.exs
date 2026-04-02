defmodule PenguinMemories.EditableAlbumParentsTest do
  use PenguinMemories.DataCase

  alias PenguinMemories.Database.Impl.Backend.Album, as: AlbumBackend
  alias PenguinMemories.Database.Query
  alias PenguinMemories.Photos.Album

  describe "edit_changeset with album_parents" do
    test "adds new parent relationships" do
      # Create test albums
      {:ok, child} = create_album("Child Album")
      {:ok, parent1} = create_album("Parent 1")
      {:ok, parent2} = create_album("Parent 2")

      # Prepare assoc data with new parent relationships
      assoc = %{
        album_parents_edit: [
          %{
            parent_id: parent1.id,
            context_name: "Child in Parent 1 context",
            context_sort_name: "child_parent1"
          },
          %{
            parent_id: parent2.id,
            context_name: "Child in Parent 2 context",
            context_sort_name: "child_parent2"
          }
        ]
      }

      # Apply changeset
      changeset = AlbumBackend.edit_changeset(child, %{}, assoc)
      assert changeset.valid?

      {:ok, updated_album} = Query.apply_edit_changeset(changeset)

      # Verify parent relationships were created
      assert length(updated_album.album_parents) == 2

      album_parent_1 =
        Enum.find(updated_album.album_parents, &(&1.parent_id == parent1.id))

      album_parent_2 =
        Enum.find(updated_album.album_parents, &(&1.parent_id == parent2.id))

      assert album_parent_1.context_name == "Child in Parent 1 context"
      assert album_parent_1.context_sort_name == "child_parent1"

      assert album_parent_2.context_name == "Child in Parent 2 context"
      assert album_parent_2.context_sort_name == "child_parent2"
    end

    test "removes existing parent relationships" do
      # Create test albums with existing relationship
      {:ok, child} = create_album("Child Album")
      {:ok, parent1} = create_album("Parent 1")
      {:ok, parent2} = create_album("Parent 2")

      # Establish initial relationships
      {:ok, _} =
        AlbumBackend.add_to_parent(child.id, parent1.id, %{context_name: "Initial context"})

      {:ok, _} =
        AlbumBackend.add_to_parent(child.id, parent2.id, %{context_name: "Another context"})

      child = Repo.preload(child, :album_parents, force: true)
      assert length(child.album_parents) == 2

      # Remove one parent via changeset (keeping only parent1)
      assoc = %{
        album_parents_edit: [
          %{
            parent_id: parent1.id,
            context_name: "Updated context",
            context_sort_name: "updated"
          }
        ]
      }

      changeset = AlbumBackend.edit_changeset(child, %{}, assoc)
      assert changeset.valid?

      {:ok, updated_album} = Query.apply_edit_changeset(changeset)

      # Verify only one relationship remains
      assert length(updated_album.album_parents) == 1
      remaining = hd(updated_album.album_parents)
      assert remaining.parent_id == parent1.id
      assert remaining.context_name == "Updated context"
      assert remaining.context_sort_name == "updated"
    end

    test "updates context information for existing relationships" do
      # Create test albums with existing relationship
      {:ok, child} = create_album("Child Album")
      {:ok, parent} = create_album("Parent Album")

      {:ok, _} =
        AlbumBackend.add_to_parent(child.id, parent.id, %{
          context_name: "Original context",
          context_sort_name: "original"
        })

      child = Repo.preload(child, :album_parents, force: true)

      # Update context information via changeset
      assoc = %{
        album_parents_edit: [
          %{
            parent_id: parent.id,
            context_name: "Updated context name",
            context_sort_name: "updated_sort"
          }
        ]
      }

      changeset = AlbumBackend.edit_changeset(child, %{}, assoc)
      assert changeset.valid?

      {:ok, updated_album} = Query.apply_edit_changeset(changeset)

      # Verify context was updated
      assert length(updated_album.album_parents) == 1
      album_parent = hd(updated_album.album_parents)
      assert album_parent.parent_id == parent.id
      assert album_parent.context_name == "Updated context name"
      assert album_parent.context_sort_name == "updated_sort"
    end

    test "prevents circular references" do
      # Create test albums in a hierarchy: grandparent -> parent -> child
      {:ok, grandparent} = create_album("Grandparent")
      {:ok, parent} = create_album("Parent")
      {:ok, child} = create_album("Child")

      {:ok, _} = AlbumBackend.add_to_parent(parent.id, grandparent.id)
      {:ok, _} = AlbumBackend.add_to_parent(child.id, parent.id)

      child = Repo.preload(child, :album_parents, force: true)

      # Try to add grandparent as child's parent (would create circular reference)
      assoc = %{
        album_parents_edit: [
          %{parent_id: parent.id, context_name: "Existing parent"},
          %{parent_id: grandparent.id, context_name: "Would create cycle"}
        ]
      }

      changeset = AlbumBackend.edit_changeset(child, %{}, assoc)

      # Changeset should have errors due to circular reference
      refute changeset.valid?
      assert Keyword.has_key?(changeset.errors, :album_parents_edit)
    end

    test "handles empty album_parents list (removes all relationships)" do
      # Create test albums with existing relationships
      {:ok, child} = create_album("Child Album")
      {:ok, parent1} = create_album("Parent 1")
      {:ok, parent2} = create_album("Parent 2")

      {:ok, _} = AlbumBackend.add_to_parent(child.id, parent1.id)
      {:ok, _} = AlbumBackend.add_to_parent(child.id, parent2.id)

      child = Repo.preload(child, :album_parents, force: true)
      assert length(child.album_parents) == 2

      # Remove all relationships via empty list
      assoc = %{album_parents_edit: []}

      changeset = AlbumBackend.edit_changeset(child, %{}, assoc)
      assert changeset.valid?

      {:ok, updated_album} = Query.apply_edit_changeset(changeset)

      # Verify all relationships were removed
      assert updated_album.album_parents == []
    end

    test "handles mixed add, update, and remove operations" do
      # Create test albums
      {:ok, child} = create_album("Child Album")
      # Will be kept and updated
      {:ok, parent1} = create_album("Parent 1")
      # Will be removed
      {:ok, parent2} = create_album("Parent 2")
      # Will be added
      {:ok, parent3} = create_album("Parent 3")

      # Establish initial relationships
      {:ok, _} =
        AlbumBackend.add_to_parent(child.id, parent1.id, %{
          context_name: "Original P1",
          context_sort_name: "orig_p1"
        })

      {:ok, _} =
        AlbumBackend.add_to_parent(child.id, parent2.id, %{context_name: "Will be removed"})

      child = Repo.preload(child, :album_parents, force: true)
      assert length(child.album_parents) == 2

      # Apply mixed operations: update parent1, remove parent2, add parent3
      assoc = %{
        album_parents_edit: [
          %{
            parent_id: parent1.id,
            context_name: "Updated P1",
            context_sort_name: "updated_p1"
          },
          %{
            parent_id: parent3.id,
            context_name: "New P3",
            context_sort_name: "new_p3"
          }
        ]
      }

      changeset = AlbumBackend.edit_changeset(child, %{}, assoc)
      assert changeset.valid?

      {:ok, updated_album} = Query.apply_edit_changeset(changeset)

      # Verify final state
      assert length(updated_album.album_parents) == 2

      parent1_rel = Enum.find(updated_album.album_parents, &(&1.parent_id == parent1.id))
      parent3_rel = Enum.find(updated_album.album_parents, &(&1.parent_id == parent3.id))

      # Parent 1 should be updated
      assert parent1_rel.context_name == "Updated P1"
      assert parent1_rel.context_sort_name == "updated_p1"

      # Parent 3 should be newly added  
      assert parent3_rel.context_name == "New P3"
      assert parent3_rel.context_sort_name == "new_p3"

      # Parent 2 should be gone
      refute Enum.any?(updated_album.album_parents, &(&1.parent_id == parent2.id))
    end

    # Helper function to create albums

    test "handles Album objects from UI selection" do
      # Create test albums
      {:ok, child} = create_album("Child Album")
      {:ok, parent1} = create_album("Parent 1")
      {:ok, parent2} = create_album("Parent 2")

      # Simulate UI passing Album objects (what ObjectSelectComponent provides)
      assoc = %{
        album_parents_edit: [parent1, parent2]
      }

      # Apply changeset
      changeset = AlbumBackend.edit_changeset(child, %{}, assoc)
      assert changeset.valid?

      {:ok, updated_album} = Query.apply_edit_changeset(changeset)

      # Verify parent relationships were created with default context
      assert length(updated_album.album_parents) == 2

      album_parent_1 =
        Enum.find(updated_album.album_parents, &(&1.parent_id == parent1.id))

      album_parent_2 =
        Enum.find(updated_album.album_parents, &(&1.parent_id == parent2.id))

      # Should use default context (nil values, will fall back to album name)
      assert album_parent_1.context_name == nil
      assert album_parent_1.context_sort_name == nil

      assert album_parent_2.context_name == nil
      assert album_parent_2.context_sort_name == nil
    end
  end

  # Helper function to create albums
  defp create_album(name) do
    Repo.insert(%Album{name: name, sort_name: String.downcase(name)})
  end
end
