defmodule PenguinMemories.BulkUpdateAlbumParentsTest do
  use PenguinMemories.DataCase

  alias PenguinMemories.Database.Impl.Backend.Album, as: AlbumBackend
  alias PenguinMemories.Database.Query
  alias PenguinMemories.Photos.{Album, AlbumUpdate}

  describe "bulk update with album_parents" do
    test "update_changeset handles album_parents field" do
      # Test the form validation changeset used in bulk updates
      attrs = %{}

      assoc = %{
        album_parents_edit: [%{id: 1, name: "Test Parent"}]
      }

      enabled = MapSet.new([:album_parents_edit])

      changeset = AlbumBackend.update_changeset(attrs, assoc, enabled)

      assert changeset.valid?
      assert changeset.changes[:album_parents_edit] == [%{id: 1, name: "Test Parent"}]
    end

    test "edit_changeset with album_parents on existing album" do
      # Create test albums (this simulates what bulk update does for each album)
      {:ok, child} = Repo.insert(%Album{name: "Child Album", sort_name: "child album"})
      {:ok, parent} = Repo.insert(%Album{name: "Parent Album", sort_name: "parent album"})

      # Preload album_parents association
      child = Repo.preload(child, :album_parents)

      # This simulates what happens during bulk update for each individual album
      assoc = %{
        # UI provides Album structs
        album_parents_edit: [parent]
      }

      changeset = AlbumBackend.edit_changeset(child, %{}, assoc)

      if changeset.valid? do
        {:ok, _updated_album} = Query.apply_edit_changeset(changeset)
      else
        flunk("Changeset invalid: #{inspect(changeset.errors)}")
      end
    end

    test "bulk update simulation with real workflow" do
      # Create albums like in real bulk update scenario
      {:ok, child1} = Repo.insert(%Album{name: "Child 1", sort_name: "child 1"})
      {:ok, child2} = Repo.insert(%Album{name: "Child 2", sort_name: "child 2"})
      {:ok, parent} = Repo.insert(%Album{name: "Parent Album", sort_name: "parent album"})

      albums = [child1, child2]

      # This simulates the bulk update process
      results =
        Enum.map(albums, fn album ->
          # Preload associations like bulk update does
          album = Repo.preload(album, :album_parents)

          # Apply the same changes to each album
          assoc = %{album_parents_edit: [parent]}

          changeset = AlbumBackend.edit_changeset(album, %{}, assoc)

          if changeset.valid? do
            Query.apply_edit_changeset(changeset)
          else
            {:error, changeset}
          end
        end)

      # Check if any failed
      failures =
        Enum.filter(results, fn
          {:ok, _} -> false
          {:error, _} -> true
        end)

      if !Enum.empty?(failures) do
        flunk("Bulk update failed for some albums")
      end
    end
  end
end
