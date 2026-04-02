defmodule PenguinMemories.UploadAlbumParentTest do
  @moduledoc """
  Test that the updated get_upload_album function works correctly with
  the new many-to-many AlbumParent relationship system.
  """

  use PenguinMemories.DataCase

  alias PenguinMemories.Photos.Album
  alias PenguinMemories.Photos.AlbumParent
  alias PenguinMemories.Repo
  alias PenguinMemories.Upload

  describe "get_upload_album with AlbumParent relationships" do
    test "creates new upload album with AlbumParent relationship" do
      # Ensure the parent "Uploads" album exists
      uploads_album = Upload.get_parent_album()
      assert uploads_album.name == "Uploads"

      # Create a new upload album
      album = Upload.get_upload_album("2024-01-Photos")

      # Verify the album was created with correct properties
      assert album.name == "2024-01-Photos"
      assert album.sort_name == "2024-01-Photos"
      assert album.reindex == true
      # Should be nil in new system
      assert album.parent_id == nil

      # Verify the AlbumParent relationship was created
      album_parent = Repo.get_by(AlbumParent, album_id: album.id, parent_id: uploads_album.id)
      assert album_parent != nil
      assert album_parent.album_id == album.id
      assert album_parent.parent_id == uploads_album.id
      assert album_parent.context_name == nil
      assert album_parent.context_sort_name == nil
      assert album_parent.context_cover_photo_id == nil
    end

    test "returns existing upload album when called multiple times" do
      uploads_album = Upload.get_parent_album()

      # First call - creates the album
      album1 = Upload.get_upload_album("Existing-Album")

      # Second call - should return the same album
      album2 = Upload.get_upload_album("Existing-Album")

      # Should be the exact same album
      assert album1.id == album2.id
      assert album1.name == album2.name

      # Should still have only one AlbumParent relationship
      album_parents =
        Repo.all(
          from ap in AlbumParent,
            where: ap.album_id == ^album1.id and ap.parent_id == ^uploads_album.id
        )

      assert length(album_parents) == 1
    end

    test "handles multiple child albums under same parent" do
      uploads_album = Upload.get_parent_album()

      # Create multiple upload albums
      album1 = Upload.get_upload_album("Photos-Jan-2024")
      album2 = Upload.get_upload_album("Photos-Feb-2024")
      album3 = Upload.get_upload_album("Videos-Jan-2024")

      # All should be different albums
      assert album1.id != album2.id
      assert album1.id != album3.id
      assert album2.id != album3.id

      # All should have parent relationships to Uploads album
      album_parent1 = Repo.get_by(AlbumParent, album_id: album1.id, parent_id: uploads_album.id)
      album_parent2 = Repo.get_by(AlbumParent, album_id: album2.id, parent_id: uploads_album.id)
      album_parent3 = Repo.get_by(AlbumParent, album_id: album3.id, parent_id: uploads_album.id)

      assert album_parent1 != nil
      assert album_parent2 != nil
      assert album_parent3 != nil

      # Query should find the correct albums by name
      found_album1 = Upload.get_upload_album("Photos-Jan-2024")
      found_album2 = Upload.get_upload_album("Photos-Feb-2024")
      found_album3 = Upload.get_upload_album("Videos-Jan-2024")

      assert found_album1.id == album1.id
      assert found_album2.id == album2.id
      assert found_album3.id == album3.id
    end

    test "query correctly finds child albums using AlbumParent join" do
      _uploads_album = Upload.get_parent_album()

      # Create an album with the new system
      album = Upload.get_upload_album("Test-Album")

      # Create another album that is NOT a child of uploads (different parent)
      {:ok, other_parent} = Repo.insert(%Album{name: "Other Parent", sort_name: "other"})
      {:ok, other_child} = Repo.insert(%Album{name: "Test-Album", sort_name: "test-album"})

      # Create relationship for the other child with different parent
      {:ok, _} =
        Repo.insert(%AlbumParent{
          album_id: other_child.id,
          parent_id: other_parent.id,
          context_name: nil,
          context_sort_name: nil,
          context_cover_photo_id: nil
        })

      # The query should find the correct album (the one that's a child of Uploads)
      found_album = Upload.get_upload_album("Test-Album")
      # Should find the upload album, not the other one
      assert found_album.id == album.id
      assert found_album.id != other_child.id
    end
  end
end
