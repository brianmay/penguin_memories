defmodule PenguinMemories.ContextAwareChildrenTest do
  use PenguinMemories.DataCase

  alias PenguinMemories.Database.Impl.Backend.Album
  alias PenguinMemories.Photos.{Album, AlbumParent}

  describe "Children via Context field" do
    test "displays context-aware names for children instead of original names" do
      # Create the parent albums
      {:ok, memorial_services} =
        Repo.insert(%Album{name: "Memorial Services", sort_name: "Funerals"})

      {:ok, travel_adventures} =
        Repo.insert(%Album{name: "Travel Adventures", sort_name: "Travel"})

      # Create the child album
      {:ok, orbost_album} = Repo.insert(%Album{name: "Orbost Original", sort_name: "Orbost"})

      # Create the many-to-many relationships with context names
      {:ok, _} =
        Repo.insert(%AlbumParent{
          album_id: orbost_album.id,
          parent_id: memorial_services.id,
          context_name: "Uncle Peter's Funeral in Orbost",
          context_sort_name: "Uncle Peter's Funeral"
        })

      {:ok, _} =
        Repo.insert(%AlbumParent{
          album_id: orbost_album.id,
          parent_id: travel_adventures.id,
          context_name: "Orbost Great Ocean Road Trip",
          context_sort_name: "Orbost Trip"
        })

      # Test Memorial Services shows the correct context name for its child
      memorial_album = Repo.get(Album, memorial_services.id) |> Repo.preload(:album_children)

      assert length(memorial_album.album_children) == 1
      child_relationship = List.first(memorial_album.album_children)
      assert child_relationship.context_name == "Uncle Peter's Funeral in Orbost"
      assert child_relationship.album_id == orbost_album.id

      # Test Travel Adventures shows the different context name for the same child
      travel_album = Repo.get(Album, travel_adventures.id) |> Repo.preload(:album_children)

      assert length(travel_album.album_children) == 1
      child_relationship = List.first(travel_album.album_children)
      assert child_relationship.context_name == "Orbost Great Ocean Road Trip"
      assert child_relationship.album_id == orbost_album.id

      # Verify the original album name is different from context names
      original_album = Repo.get(Album, orbost_album.id)
      assert original_album.name == "Orbost Original"
      assert original_album.name != "Uncle Peter's Funeral in Orbost"
      assert original_album.name != "Orbost Great Ocean Road Trip"
    end
  end
end
