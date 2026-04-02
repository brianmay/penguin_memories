defmodule PenguinMemories.MultipleBreadcrumbsTest do
  @moduledoc """
  Test multiple breadcrumb trails functionality with real album data.
  """

  use PenguinMemories.DataCase

  alias PenguinMemories.Photos.{Album, AlbumParent, AlbumPath}
  alias PenguinMemories.Database.{PathCompute, Query}

  describe "Multiple breadcrumb trails" do
    test "creates and displays multiple breadcrumb paths for albums with many-to-many parents" do
      # Create test album hierarchy:
      # Life Events (1) -> Memorial Services (3) -> Uncle Peter's Memorial (5)
      # Travel (2) -> Great Ocean Road (4) -> Uncle Peter's Memorial (5)

      # Create albums with required sort_name field
      {:ok, life_events} = %Album{name: "Life Events", sort_name: "Life Events"} |> Repo.insert()
      {:ok, travel} = %Album{name: "Travel", sort_name: "Travel"} |> Repo.insert()

      {:ok, memorial_services} =
        %Album{
          name: "Memorial Services",
          sort_name: "Memorial Services",
          parent_id: life_events.id
        }
        |> Repo.insert()

      {:ok, great_ocean_road} =
        %Album{name: "Great Ocean Road", sort_name: "Great Ocean Road", parent_id: travel.id}
        |> Repo.insert()

      {:ok, uncle_peters} =
        %Album{name: "Uncle Peter's Memorial", sort_name: "Uncle Peter's Memorial"}
        |> Repo.insert()

      # Create many-to-many relationships for uncle_peters album
      {:ok, _} =
        %AlbumParent{
          album_id: uncle_peters.id,
          parent_id: memorial_services.id,
          context_name: "Uncle Peter's Memorial"
        }
        |> Repo.insert()

      {:ok, _} =
        %AlbumParent{
          album_id: uncle_peters.id,
          parent_id: great_ocean_road.id,
          context_name: "Uncle Peter's Memorial"
        }
        |> Repo.insert()

      # Trigger path computation
      PathCompute.compute_and_store_paths(uncle_peters.id)

      # Check that paths were created
      paths = Repo.all(from ap in AlbumPath, where: ap.descendant_id == ^uncle_peters.id)

      assert length(paths) == 2, "Should have 2 paths for album with 2 parent hierarchies"

      # Verify path contents
      path_lengths = Enum.map(paths, & &1.path_length)

      assert 3 in path_lengths,
             "Should have 3-level path: Life Events -> Memorial Services -> Uncle Peter's"

      assert 3 in path_lengths,
             "Should have 3-level path: Travel -> Great Ocean Road -> Uncle Peter's"

      # Test breadcrumb trail query
      trails = Query.query_album_breadcrumb_trails(uncle_peters.id)
      assert length(trails) == 2, "Should return 2 breadcrumb trails"

      # Each trail should be non-empty
      Enum.each(trails, fn trail ->
        assert length(trail) > 0, "Each trail should have breadcrumb items"
      end)

      # Test the enhanced get_photo_parents_with_trails function
      result = Query.get_photo_parents_with_trails([uncle_peters])

      assert match?({:multiple_trails, _}, result), "Should return multiple trails format"
      {:multiple_trails, returned_trails} = result
      assert length(returned_trails) == 2, "Should return 2 trails"
    end

    test "falls back to direct parents for albums without stored paths" do
      # Create simple single-parent album
      {:ok, parent} = %Album{name: "Parent Album", sort_name: "Parent Album"} |> Repo.insert()

      {:ok, child} =
        %Album{name: "Child Album", sort_name: "Child Album", parent_id: parent.id}
        |> Repo.insert()

      # Don't trigger path computation - test fallback
      result = Query.get_photo_parents_with_trails([child])

      # Should fall back to direct parent approach (list format, not :multiple_trails)
      assert is_list(result), "Should fall back to list format for single parent"
    end
  end
end
