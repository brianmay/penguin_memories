defmodule PenguinMemories.AlbumListingDuplicateTest do
  @moduledoc """
  Test that albums with multiple parent relationships appear only once 
  in parent album listings, showing the correct context name.
  """

  use PenguinMemories.DataCase

  alias PenguinMemories.Database.Impl.Backend.Album, as: AlbumBackend
  alias PenguinMemories.Photos.Album
  alias PenguinMemories.Photos.AlbumParent

  describe "album listing with multiple contexts" do
    test "albums with multiple parents appear only once in parent listing" do
      # Create parent albums
      {:ok, travel_album} = Repo.insert(%Album{name: "Travel", sort_name: "travel"})

      {:ok, conferences_album} =
        Repo.insert(%Album{name: "Conferences", sort_name: "conferences"})

      {:ok, child_album} = Repo.insert(%Album{name: "Hobart Trip", sort_name: "hobart-trip"})

      # Create multiple parent relationships for child_album
      {:ok, _rel1} =
        Repo.insert(%AlbumParent{
          album_id: child_album.id,
          parent_id: travel_album.id,
          context_name: "Hobart",
          context_sort_name: nil,
          context_cover_photo_id: nil
        })

      {:ok, _rel2} =
        Repo.insert(%AlbumParent{
          album_id: child_album.id,
          parent_id: conferences_album.id,
          context_name: "LCA2009",
          context_sort_name: nil,
          context_cover_photo_id: nil
        })

      # Test query for children of travel_album
      query = from a in Album, as: :object, order_by: a.sort_name
      filtered_query = AlbumBackend.filter_by_parent_id(query, travel_album.id)
      travel_children = Repo.all(filtered_query)

      # Child should appear exactly once in travel album listing
      hobart_entries = Enum.filter(travel_children, &(&1.id == child_album.id))
      assert length(hobart_entries) == 1, "Child album should appear exactly once"

      # Should show the 'Hobart' context name
      hobart_entry = List.first(hobart_entries)
      assert hobart_entry.context_name == "Hobart"

      # Test query for children of conferences_album  
      conference_filtered_query = AlbumBackend.filter_by_parent_id(query, conferences_album.id)
      conference_children = Repo.all(conference_filtered_query)

      # Child should appear exactly once in conferences album listing
      lca_entries = Enum.filter(conference_children, &(&1.id == child_album.id))
      assert length(lca_entries) == 1, "Child album should appear exactly once"

      # Should show the 'LCA2009' context name
      lca_entry = List.first(lca_entries)
      assert lca_entry.context_name == "LCA2009"

      # Verify no duplicates in overall results
      travel_ids = Enum.map(travel_children, & &1.id)
      conference_ids = Enum.map(conference_children, & &1.id)

      assert length(travel_ids) == length(Enum.uniq(travel_ids)),
             "No duplicate IDs in travel listing"

      assert length(conference_ids) == length(Enum.uniq(conference_ids)),
             "No duplicate IDs in conference listing"
    end

    test "legacy parent_id albums still work alongside AlbumParent system" do
      # Create parent album and legacy child
      {:ok, parent_album} = Repo.insert(%Album{name: "Old Parent", sort_name: "old-parent"})

      {:ok, legacy_child} =
        Repo.insert(%Album{
          name: "Legacy Child",
          sort_name: "legacy-child",
          # Use old parent_id system
          parent_id: parent_album.id
        })

      # Create modern child with AlbumParent relationship
      {:ok, modern_child} = Repo.insert(%Album{name: "Modern Child", sort_name: "modern-child"})

      {:ok, _rel} =
        Repo.insert(%AlbumParent{
          album_id: modern_child.id,
          parent_id: parent_album.id,
          context_name: "Modern Context",
          context_sort_name: nil,
          context_cover_photo_id: nil
        })

      # Query should find both children
      query = from a in Album, as: :object, order_by: a.sort_name
      filtered_query = AlbumBackend.filter_by_parent_id(query, parent_album.id)
      children = Repo.all(filtered_query)

      child_ids = Enum.map(children, & &1.id)
      assert legacy_child.id in child_ids, "Legacy child should be found"
      assert modern_child.id in child_ids, "Modern child should be found"

      # Check context information
      modern_entry = Enum.find(children, &(&1.id == modern_child.id))
      legacy_entry = Enum.find(children, &(&1.id == legacy_child.id))

      assert modern_entry.context_name == "Modern Context"
      # Legacy entries have no context
      assert legacy_entry.context_name == nil
    end
  end
end
