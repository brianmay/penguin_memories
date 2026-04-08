defmodule PenguinMemories.ContextAwareParentsTest do
  use PenguinMemories.DataCase

  alias PenguinMemories.Database.Impl.Backend.Album
  alias PenguinMemories.Photos.{Album, AlbumParent}

  describe "Parents field with context information" do
    test "displays parent names with context information about how child appears in parent" do
      # Create the parent albums
      {:ok, memorial_services} =
        Repo.insert(%Album{name: "Memorial Services", sort_name: "Funerals"})

      {:ok, travel_adventures} =
        Repo.insert(%Album{name: "Travel Adventures", sort_name: "Travel"})

      # Create the child album
      {:ok, orbost_album} = Repo.insert(%Album{name: "Orbost Original", sort_name: "Orbost"})

      # Create the many-to-many relationships with context names
      {:ok, _memorial_relationship} =
        Repo.insert(%AlbumParent{
          album_id: orbost_album.id,
          parent_id: memorial_services.id,
          context_name: "Uncle Peter's Funeral in Orbost",
          context_sort_name: "Uncle Peter's Funeral"
        })

      {:ok, _travel_relationship} =
        Repo.insert(%AlbumParent{
          album_id: orbost_album.id,
          parent_id: travel_adventures.id,
          context_name: "Orbost Great Ocean Road Trip",
          context_sort_name: "Orbost Trip"
        })

      # Test the child album shows context information for its parents
      child_album = Repo.get(Album, orbost_album.id) |> Repo.preload(album_parents: :parent)

      assert length(child_album.album_parents) == 2

      # Find memorial services parent relationship
      memorial_parent_rel =
        Enum.find(child_album.album_parents, fn rel ->
          rel.parent_id == memorial_services.id
        end)

      assert memorial_parent_rel != nil
      assert memorial_parent_rel.parent.name == "Memorial Services"
      assert memorial_parent_rel.context_name == "Uncle Peter's Funeral in Orbost"

      # Find travel adventures parent relationship
      travel_parent_rel =
        Enum.find(child_album.album_parents, fn rel ->
          rel.parent_id == travel_adventures.id
        end)

      assert travel_parent_rel != nil
      assert travel_parent_rel.parent.name == "Travel Adventures"
      assert travel_parent_rel.context_name == "Orbost Great Ocean Road Trip"

      # Verify that the context names represent how the CHILD appears in each parent
      # (not how the parent appears to the child)
      assert memorial_parent_rel.context_name != memorial_parent_rel.parent.name
      assert travel_parent_rel.context_name != travel_parent_rel.parent.name

      # The context names should be different from the original album name
      assert memorial_parent_rel.context_name != child_album.name
      assert travel_parent_rel.context_name != child_album.name
    end
  end
end
