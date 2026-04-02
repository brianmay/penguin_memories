defmodule PenguinMemories.AlbumCreationTest do
  @moduledoc """
  Test that album creation works correctly with the new many-to-many 
  AlbumParent relationship system, specifically testing the UI workflow
  through get_create_child_changeset and apply_insert.
  """

  use PenguinMemories.DataCase

  alias PenguinMemories.Database.Query
  alias PenguinMemories.Photos.Album
  alias PenguinMemories.Photos.AlbumParent

  describe "album creation with parents" do
    test "creates child album with AlbumParent relationship via UI workflow" do
      # Create a parent album first
      {:ok, parent_album} =
        Repo.insert(%Album{
          name: "Test Parent Album",
          sort_name: "test-parent-album"
        })

      # Test creating child album using the UI workflow  
      {assoc, changeset} =
        Query.get_create_child_changeset(
          parent_album,
          %{
            "name" => "Test Child Album",
            "sort_name" => "test-child-album"
          },
          %{}
        )

      # Changeset should be valid
      assert changeset.valid?

      # Should have album_parents_edit data set up
      assert Map.has_key?(assoc, :album_parents_edit)
      assert length(assoc.album_parents_edit) == 1

      album_parent_data = List.first(assoc.album_parents_edit)
      assert album_parent_data.id == parent_album.id
      assert album_parent_data.name == parent_album.name

      # Apply the changeset to create the album
      {:ok, child_album} = Query.apply_edit_changeset(changeset)

      # Verify child album was created correctly
      assert child_album.name == "Test Child Album"
      assert child_album.sort_name == "test-child-album"
      # Should NOT use legacy parent_id field
      assert child_album.parent_id == nil

      # Verify AlbumParent relationship was created
      album_parent =
        Repo.get_by(AlbumParent,
          album_id: child_album.id,
          parent_id: parent_album.id
        )

      assert album_parent != nil
      assert album_parent.album_id == child_album.id
      assert album_parent.parent_id == parent_album.id
      assert album_parent.context_name == nil
      assert album_parent.context_sort_name == nil
      assert album_parent.context_cover_photo_id == nil
    end

    test "creates child album with custom context information" do
      # Create a parent album
      {:ok, parent_album} =
        Repo.insert(%Album{
          name: "Travel Album",
          sort_name: "travel-album"
        })

      # Create child with custom context
      {assoc, _changeset} =
        Query.get_create_child_changeset(
          parent_album,
          %{
            "name" => "Trip to Paris",
            "sort_name" => "trip-to-paris"
          },
          %{}
        )

      # Modify assoc to include context information
      album_parent_with_context = %{
        parent_id: parent_album.id,
        context_name: "European Vacation",
        context_sort_name: "european-vacation",
        context_cover_photo_id: nil
      }

      assoc_with_context = Map.put(assoc, :album_parents_edit, [album_parent_with_context])

      # Apply changeset with custom context
      changeset =
        Query.get_edit_changeset(
          %Album{},
          %{
            "name" => "Trip to Paris",
            "sort_name" => "trip-to-paris"
          },
          assoc_with_context
        )

      {:ok, child_album} = Query.apply_edit_changeset(changeset)

      # Verify relationship includes context information
      album_parent =
        Repo.get_by(AlbumParent,
          album_id: child_album.id,
          parent_id: parent_album.id
        )

      assert album_parent != nil
      assert album_parent.context_name == "European Vacation"
      assert album_parent.context_sort_name == "european-vacation"
    end

    test "handles multiple parent relationships for new album" do
      # Create two parent albums
      {:ok, parent1} =
        Repo.insert(%Album{name: "Family", sort_name: "family"})

      {:ok, parent2} =
        Repo.insert(%Album{name: "Vacations", sort_name: "vacations"})

      # Set up multiple parent relationships
      assoc = %{
        album_parents_edit: [
          %{
            parent_id: parent1.id,
            context_name: nil,
            context_sort_name: nil,
            context_cover_photo_id: nil
          },
          %{
            parent_id: parent2.id,
            context_name: nil,
            context_sort_name: nil,
            context_cover_photo_id: nil
          }
        ]
      }

      # Create changeset for new album  
      changeset =
        Query.get_edit_changeset(
          %Album{},
          %{
            "name" => "Family Vacation",
            "sort_name" => "family-vacation"
          },
          assoc
        )

      # Apply changeset
      {:ok, child_album} = Query.apply_edit_changeset(changeset)

      # Should have two AlbumParent relationships
      album_parents =
        Repo.all(
          from ap in AlbumParent,
            where: ap.album_id == ^child_album.id
        )

      assert length(album_parents) == 2

      parent_ids = Enum.map(album_parents, & &1.parent_id)
      assert parent1.id in parent_ids
      assert parent2.id in parent_ids
    end
  end
end
