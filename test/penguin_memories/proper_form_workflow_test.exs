defmodule PenguinMemories.ProperFormWorkflowTest do
  use PenguinMemories.DataCase

  alias PenguinMemories.Database.Impl.Backend.Album
  alias PenguinMemories.Database.Query
  alias PenguinMemories.Photos.Album, as: AlbumSchema
  alias PenguinMemories.Repo

  describe "proper form workflow" do
    test "validation does not apply changes immediately" do
      # Create test albums
      {:ok, parent} = create_album("Parent Album")
      {:ok, child} = create_album("Child Album")

      # Load album with current relationships
      child_with_assoc = Repo.get!(AlbumSchema, child.id) |> Repo.preload([:album_parents])

      # Simulate form validation (user adds parent in UI)
      params = %{"album_parents_edit" => [parent]}
      assoc = %{album_parents_edit: [parent]}

      changeset = Album.edit_changeset(child_with_assoc, params, assoc)
      assert changeset.valid?, "Changeset should be valid"

      # Verify that validation does NOT apply changes immediately
      child_after_validation = Repo.get!(AlbumSchema, child.id) |> Repo.preload([:album_parents])

      assert length(child_after_validation.album_parents) == 0,
             "Validation should not apply changes immediately"

      # Verify operations are stored in changeset for later application
      stored_operations = Ecto.Changeset.get_change(changeset, :album_parents_operations)
      assert stored_operations != nil, "Operations should be stored in changeset"
      assert length(stored_operations.to_add) == 1, "Should have one operation to add"

      # Now simulate form save (user clicks Save button)
      {:ok, updated_album} = Query.apply_edit_changeset(changeset)

      # Verify changes are only applied after form save
      assert length(updated_album.album_parents) == 1, "Changes should be applied after form save"

      assert Enum.any?(updated_album.album_parents, &(&1.parent_id == parent.id)),
             "Parent relationship should exist after save"
    end

    test "form can be cancelled without applying changes" do
      # Create test albums
      {:ok, parent} = create_album("Parent Album")
      {:ok, child} = create_album("Child Album")

      # Load album with current relationships
      child_with_assoc = Repo.get!(AlbumSchema, child.id) |> Repo.preload([:album_parents])

      # Simulate form validation (user adds parent in UI)
      params = %{"album_parents_edit" => [parent]}
      assoc = %{album_parents_edit: [parent]}

      changeset = Album.edit_changeset(child_with_assoc, params, assoc)
      assert changeset.valid?, "Changeset should be valid"

      # Simulate user cancelling form (no call to apply_edit_changeset)
      # Check that no changes were applied
      child_after_cancel = Repo.get!(AlbumSchema, child.id) |> Repo.preload([:album_parents])

      assert length(child_after_cancel.album_parents) == 0,
             "No changes should be applied when form is cancelled"
    end
  end

  defp create_album(name) do
    Repo.insert(%AlbumSchema{name: name, sort_name: String.downcase(name)})
  end
end
