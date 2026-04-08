defmodule PenguinMemories.LegacyParentClearingTest do
  @moduledoc """
  Test that legacy parent_id is automatically cleared when new album_parents relationships are added.
  This prevents the "sometimes works, sometimes doesn't" issue where albums would have both
  legacy single-parent and new many-to-many parent relationships simultaneously.
  """
  use PenguinMemories.DataCase

  alias PenguinMemories.Database.Impl.Backend.Album, as: AlbumBackend
  alias PenguinMemories.Database.Query
  alias PenguinMemories.Photos.Album

  describe "legacy parent_id clearing" do
    test "automatically clears parent_id when new album_parents relationships are added" do
      # Create parent albums
      {:ok, legacy_parent} = create_album("Legacy Parent")
      {:ok, new_parent1} = create_album("New Parent 1")
      {:ok, new_parent2} = create_album("New Parent 2")

      # Create child album with legacy parent_id set
      {:ok, child_album} = create_album("Child Album", %{parent_id: legacy_parent.id})

      # Verify child has legacy parent set
      child = Repo.get!(Album, child_album.id) |> Repo.preload(:album_parents)
      assert child.parent_id == legacy_parent.id
      assert Enum.empty?(child.album_parents)

      # Now add new parent relationships via edit_changeset
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

      # Create edit changeset with new parents using the Album backend
      changeset = AlbumBackend.edit_changeset(child, %{}, %{album_parents_edit: new_parents_data})

      # Verify changeset is valid and parent_id is automatically set to nil
      assert changeset.valid?
      assert changeset.changes[:parent_id] == nil
      assert changeset.changes[:album_parents_edit] == new_parents_data

      # Apply the changeset
      {:ok, _updated_album} = Repo.update(changeset)
      {:ok, updated_album} = Query.apply_edit_changeset(changeset)

      # Verify legacy parent_id is cleared and new relationships exist
      final_album = Repo.get!(Album, updated_album.id) |> Repo.preload(:album_parents)
      assert final_album.parent_id == nil
      assert length(final_album.album_parents) == 2

      parent_ids = Enum.map(final_album.album_parents, & &1.parent_id) |> Enum.sort()
      assert parent_ids == [new_parent1.id, new_parent2.id] |> Enum.sort()
    end

    test "preserves parent_id when no new album_parents are added" do
      # Create parent album
      {:ok, legacy_parent} = create_album("Legacy Parent")

      # Create child album with legacy parent_id set
      {:ok, child_album} = create_album("Child Album", %{parent_id: legacy_parent.id})

      # Update album with other fields but no new parents
      changeset =
        AlbumBackend.edit_changeset(child_album, %{description: "Updated description"}, %{})

      # Verify parent_id is not changed
      assert changeset.valid?
      refute Map.has_key?(changeset.changes, :parent_id)

      # Apply the changeset
      {:ok, updated_album} = Repo.update(changeset)

      # Verify legacy parent_id is preserved
      final_album = Repo.get!(Album, updated_album.id)
      assert final_album.parent_id == legacy_parent.id
    end

    test "handles empty album_parents list without clearing parent_id" do
      # Create parent album
      {:ok, legacy_parent} = create_album("Legacy Parent")

      # Create child album with legacy parent_id set
      {:ok, child_album} = create_album("Child Album", %{parent_id: legacy_parent.id})

      # Update album with empty album_parents list (not the same as adding new parents)
      changeset = AlbumBackend.edit_changeset(child_album, %{}, %{album_parents_edit: []})

      # Verify parent_id is not changed when album_parents list is empty
      assert changeset.valid?
      refute Map.has_key?(changeset.changes, :parent_id)

      # Apply the changeset
      {:ok, updated_album} = Repo.update(changeset)

      # Verify legacy parent_id is preserved
      final_album = Repo.get!(Album, updated_album.id)
      assert final_album.parent_id == legacy_parent.id
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
