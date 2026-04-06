defmodule PenguinMemories.SimultaneousParentSystemUpdateTest do
  @moduledoc """
  Test what happens when both parent_id (legacy) and album_parents_edit (new) are updated simultaneously.
  This is an edge case that could occur during bulk operations.
  """
  use PenguinMemories.DataCase

  alias PenguinMemories.Database.Impl.Backend.Album, as: AlbumBackend
  alias PenguinMemories.Photos.{Album, AlbumUpdate}

  describe "simultaneous parent system updates" do
    test "edit_changeset with both parent_id and album_parents_edit - album_parents_edit wins" do
      # Create albums
      {:ok, legacy_parent} = create_album("Legacy Parent")
      {:ok, new_parent1} = create_album("New Parent 1")
      {:ok, new_parent2} = create_album("New Parent 2")
      {:ok, conflicting_parent} = create_album("Conflicting Parent")
      {:ok, child_album} = create_album("Child Album")

      # Prepare simultaneous updates
      # Legacy system update
      attrs = %{parent_id: conflicting_parent.id}

      new_parents_data = [
        %{
          parent_id: new_parent1.id,
          parent_name: new_parent1.name,
          context_name: nil,
          context_sort_name: nil,
          context_cover_photo_id: nil
        },
        %{
          parent_id: new_parent2.id,
          parent_name: new_parent2.name,
          context_name: nil,
          context_sort_name: nil,
          context_cover_photo_id: nil
        }
      ]

      # New system update
      assoc = %{album_parents_edit: new_parents_data}

      # Apply both simultaneously via edit_changeset
      changeset = AlbumBackend.edit_changeset(child_album, attrs, assoc)

      # Check what happens - my logic should set parent_id to nil despite attrs
      assert changeset.valid?

      # The changeset should contain parent_id: nil (cleared by my logic)
      # despite the attrs trying to set it to conflicting_parent.id
      assert changeset.changes[:parent_id] == nil
      assert changeset.changes[:album_parents_edit] == new_parents_data

      # Apply the changeset
      {:ok, updated_album} = PenguinMemories.Database.Query.apply_edit_changeset(changeset)

      # Verify the result - new parent system should win
      final_album = Repo.get!(Album, updated_album.id) |> Repo.preload(:album_parents)
      # Not conflicting_parent.id
      assert final_album.parent_id == nil
      assert length(final_album.album_parents) == 2

      parent_ids = Enum.map(final_album.album_parents, & &1.parent_id) |> Enum.sort()
      assert parent_ids == [new_parent1.id, new_parent2.id] |> Enum.sort()
    end

    test "update_changeset with both parent and album_parents_edit enabled" do
      # Create albums
      {:ok, legacy_parent} = create_album("Legacy Parent")
      {:ok, new_parent} = create_album("New Parent")
      {:ok, conflicting_parent} = create_album("Conflicting Parent")

      # Simulate bulk update with both fields enabled
      attrs = %{}

      assoc = %{
        # Legacy parent system
        parent: conflicting_parent,
        album_parents_edit: [
          %{
            parent_id: new_parent.id,
            parent_name: new_parent.name,
            context_name: nil,
            context_sort_name: nil,
            context_cover_photo_id: nil
          }
        ]
      }

      enabled = MapSet.new([:parent, :album_parents_edit])

      # Create update changeset
      update_changeset = AlbumBackend.update_changeset(attrs, assoc, enabled)

      # Check what's in the changeset
      IO.puts("Update changeset changes: #{inspect(update_changeset.changes)}")

      # This changeset would be applied to albums during bulk update
      assert update_changeset.valid?
      # Legacy system
      assert Map.has_key?(update_changeset.changes, :parent)
      # New system
      assert Map.has_key?(update_changeset.changes, :album_parents_edit)

      # Now let's see what happens when this gets applied to an actual album
      {:ok, child_album} = create_album("Child Album", %{parent_id: legacy_parent.id})

      # Simulate the bulk update process by converting the AlbumUpdate changeset
      # to changes and assoc that would be passed to edit_changeset
      # Only non-assoc fields
      changes = Map.take(update_changeset.changes, [:revised])
      assoc_data = %{}

      # Add parent info
      if Map.has_key?(update_changeset.changes, :parent) do
        assoc_data = Map.put(assoc_data, :parent, update_changeset.changes.parent)
      end

      # Add album_parents_edit info  
      if Map.has_key?(update_changeset.changes, :album_parents_edit) do
        assoc_data =
          Map.put(assoc_data, :album_parents_edit, update_changeset.changes.album_parents_edit)
      end

      # Apply via edit_changeset (this is what happens in bulk updates)
      final_changeset = AlbumBackend.edit_changeset(child_album, changes, assoc_data)

      IO.puts("Final changeset changes: #{inspect(final_changeset.changes)}")

      # My logic should still clear parent_id when album_parents_edit is present
      assert final_changeset.valid?
      # Should be cleared
      assert final_changeset.changes[:parent_id] == nil
      assert final_changeset.changes[:album_parents_edit] == assoc.album_parents_edit
    end

    test "bulk update behavior with conflicting parent systems" do
      # This tests the actual bulk update path with both fields enabled

      # Create albums
      {:ok, legacy_parent} = create_album("Legacy Parent")
      {:ok, new_parent} = create_album("New Parent")
      {:ok, conflicting_parent} = create_album("Conflicting Parent")
      {:ok, child1} = create_album("Child 1", %{parent_id: legacy_parent.id})
      {:ok, child2} = create_album("Child 2", %{parent_id: legacy_parent.id})

      # Create a query for these children
      album_ids = [child1.id, child2.id]
      query = from a in Album, as: :object, where: a.id in ^album_ids

      # Prepare bulk update with both parent systems
      updates = [
        # Legacy parent system update
        %PenguinMemories.Database.Updates.UpdateChange{
          field_id: :parent,
          change: :set,
          type: {:single, nil},
          value: conflicting_parent
        },
        # New parent system update
        %PenguinMemories.Database.Updates.UpdateChange{
          field_id: :album_parents_edit,
          change: :set,
          type: {:multiple, nil},
          value: [
            %{
              parent_id: new_parent.id,
              parent_name: new_parent.name,
              context_name: nil,
              context_sort_name: nil,
              context_cover_photo_id: nil
            }
          ]
        }
      ]

      # Apply bulk update - this should go through my special album handling
      result = PenguinMemories.Database.Updates.apply_updates(updates, query)

      # Should succeed
      assert result == :ok

      # Check final state - new parent system should win
      for child <- [child1, child2] do
        updated_child = Repo.get!(Album, child.id) |> Repo.preload(:album_parents)
        # Not conflicting_parent.id
        assert updated_child.parent_id == nil
        assert length(updated_child.album_parents) == 1
        assert hd(updated_child.album_parents).parent_id == new_parent.id
      end
    end
  end

  defp create_album(name, attrs \\ %{}) do
    default_attrs = %{
      name: name,
      sort_name: name
    }

    merged_attrs = Map.merge(default_attrs, attrs)

    album =
      %Album{}
      |> Ecto.Changeset.cast(merged_attrs, [:name, :sort_name, :description, :parent_id])
      |> Ecto.Changeset.validate_required([:name, :sort_name])
      |> Repo.insert!()

    {:ok, album}
  end
end
