defmodule PenguinMemories.NoDoubleParentSystemTest do
  @moduledoc """
  Test that albums cannot have both legacy parent_id and new album_parents simultaneously.
  This prevents the "double parent" issue where albums appear multiple times in listings.
  """
  use PenguinMemories.DataCase

  alias PenguinMemories.Database.Impl.Backend.Album, as: AlbumBackend
  alias PenguinMemories.Database.Query
  alias PenguinMemories.Photos.{Album, AlbumParent}

  describe "no double parent system" do
    test "albums appear only once in parent listings regardless of relationship type" do
      # Create parent albums
      {:ok, parent_album} = create_album("Parent Album")
      {:ok, other_parent} = create_album("Other Parent")

      # Create child album with legacy parent_id
      {:ok, child_album} = create_album("Child Album", %{parent_id: parent_album.id})

      # Verify child appears once in parent's children
      query = from a in Album, as: :object, order_by: a.sort_name
      filtered_query = AlbumBackend.filter_by_parent_id(query, parent_album.id)
      children_via_legacy = Repo.all(filtered_query)

      assert length(children_via_legacy) == 1
      assert hd(children_via_legacy).id == child_album.id
      assert hd(children_via_legacy).parent_id == parent_album.id

      # Now add new album_parents relationship to different parent
      new_parents_data = [
        %{
          parent_id: other_parent.id,
          parent_name: other_parent.name,
          context_name: "Test Context",
          context_sort_name: nil,
          context_cover_photo_id: nil
        }
      ]

      # Create changeset that should clear legacy parent_id
      changeset =
        AlbumBackend.edit_changeset(child_album, %{}, %{album_parents_edit: new_parents_data})

      # Apply the changeset
      {:ok, _updated_album} = Query.apply_edit_changeset(changeset)

      # Reload the child to see final state
      updated_child = Repo.get!(Album, child_album.id) |> Repo.preload(:album_parents)

      # Verify legacy parent_id is cleared
      assert updated_child.parent_id == nil
      assert length(updated_child.album_parents) == 1
      assert hd(updated_child.album_parents).parent_id == other_parent.id

      # Verify child no longer appears in old parent's children (legacy system)
      children_via_legacy_after = Repo.all(filtered_query)
      assert children_via_legacy_after == []

      # Verify child appears in new parent's children (new system)
      filtered_query_new = AlbumBackend.filter_by_parent_id(query, other_parent.id)
      children_via_new = Repo.all(filtered_query_new)

      assert children_via_new != []
      assert hd(children_via_new).id == child_album.id
      assert hd(children_via_new).context_name == "Test Context"
    end

    test "bulk update correctly handles transition from legacy to new parent system" do
      # Create parent albums
      {:ok, legacy_parent} = create_album("Legacy Parent")
      {:ok, new_parent1} = create_album("New Parent 1")
      {:ok, new_parent2} = create_album("New Parent 2")

      # Create multiple children with legacy parent_id
      {:ok, child1} = create_album("Child 1", %{parent_id: legacy_parent.id})
      {:ok, child2} = create_album("Child 2", %{parent_id: legacy_parent.id})

      # Verify both children appear in legacy parent listing
      query = from a in Album, as: :object, order_by: a.sort_name
      filtered_query = AlbumBackend.filter_by_parent_id(query, legacy_parent.id)
      legacy_children = Repo.all(filtered_query)

      assert length(legacy_children) == 2
      legacy_ids = Enum.map(legacy_children, & &1.id) |> Enum.sort()
      assert legacy_ids == [child1.id, child2.id] |> Enum.sort()

      # Perform bulk update to transition both children to new parent system
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

      # Apply bulk update to both children
      for child <- [child1, child2] do
        changeset =
          AlbumBackend.edit_changeset(child, %{}, %{album_parents_edit: new_parents_data})

        {:ok, _updated_album} = Query.apply_edit_changeset(changeset)
      end

      # Verify no children appear in legacy parent anymore
      legacy_children_after = Repo.all(filtered_query)
      assert legacy_children_after == []

      # Verify children appear in new parents
      for new_parent <- [new_parent1, new_parent2] do
        new_filtered_query = AlbumBackend.filter_by_parent_id(query, new_parent.id)
        new_children = Repo.all(new_filtered_query)

        assert length(new_children) == 2
        new_children_ids = Enum.map(new_children, & &1.id) |> Enum.sort()
        assert new_children_ids == [child1.id, child2.id] |> Enum.sort()
      end

      # Verify final state - both children have cleared parent_id and new relationships
      for child <- [child1, child2] do
        updated_child = Repo.get!(Album, child.id) |> Repo.preload(:album_parents)
        assert updated_child.parent_id == nil
        assert length(updated_child.album_parents) == 2

        parent_ids = Enum.map(updated_child.album_parents, & &1.parent_id) |> Enum.sort()
        assert parent_ids == [new_parent1.id, new_parent2.id] |> Enum.sort()
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
