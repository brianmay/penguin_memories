defmodule PenguinMemories.BreadcrumbRegressionTest do
  @moduledoc """
  Test that replicates the exact user scenario where updating context_name
  from "Orbost Great Ocean Road Trip" to "21Orbost Great Ocean Road Trip"
  should update the breadcrumbs after reindexing.
  """

  use PenguinMemories.DataCase

  alias PenguinMemories.Database.Query
  alias PenguinMemories.Photos.Album
  alias PenguinMemories.Photos.AlbumParent
  alias PenguinMemories.Photos.AlbumPath
  alias PenguinMemories.Repo

  describe "breadcrumb regression test" do
    test "updating context_name from 'Orbost Great Ocean Road Trip' to '21Orbost Great Ocean Road Trip' updates breadcrumbs" do
      # Create the albums matching the user's scenario
      {:ok, travel_adventures} =
        Repo.insert(%Album{name: "Travel Adventures", sort_name: "Travel"})

      {:ok, orbost_album} = Repo.insert(%Album{name: "Orbost Original", sort_name: "2026-05"})

      # Create the initial relationship with the original context name
      {:ok, _album_parent} =
        Repo.insert(%AlbumParent{
          album_id: orbost_album.id,
          parent_id: travel_adventures.id,
          context_name: "Orbost Great Ocean Road Trip",
          context_sort_name: "2026-05-GOR",
          context_cover_photo_id: nil
        })

      # Initial path computation (simulating the state before the update)
      PenguinMemories.Database.PathCompute.compute_and_store_paths(orbost_album.id)

      # Verify initial breadcrumb contains the original context name
      initial_path = Repo.get_by(AlbumPath, descendant_id: orbost_album.id)
      initial_contexts = initial_path.path_contexts || %{}

      has_original_context =
        Enum.any?(Map.values(initial_contexts), fn context ->
          context_name =
            case context do
              %{"name" => name} -> name
              name when is_binary(name) -> name
              _ -> ""
            end

          String.contains?(to_string(context_name), "Orbost Great Ocean Road Trip")
        end)

      assert has_original_context,
             "Initial breadcrumb should contain 'Orbost Great Ocean Road Trip'"

      # Now update the context name using the form workflow (as the user did)
      assoc_data = %{
        album_parents_edit: [
          %{
            parent_id: travel_adventures.id,
            context_name: "21Orbost Great Ocean Road Trip",
            context_sort_name: "2026-05-GOR",
            context_cover_photo_id: nil
          }
        ]
      }

      # Apply the update through the proper form workflow
      changeset = Query.get_edit_changeset(orbost_album, %{}, assoc_data)
      {:ok, _updated_album} = Query.apply_edit_changeset(changeset)

      # Verify the database was updated correctly
      updated_album_parent =
        Repo.get_by(AlbumParent, album_id: orbost_album.id, parent_id: travel_adventures.id)

      assert updated_album_parent.context_name == "21Orbost Great Ocean Road Trip"

      # CRITICAL TEST: Verify the breadcrumbs now show the updated context name
      updated_path = Repo.get_by(AlbumPath, descendant_id: orbost_album.id)
      updated_contexts = updated_path.path_contexts || %{}

      has_updated_context =
        Enum.any?(Map.values(updated_contexts), fn context ->
          context_name =
            case context do
              %{"name" => name} -> name
              name when is_binary(name) -> name
              _ -> ""
            end

          String.contains?(to_string(context_name), "21Orbost Great Ocean Road Trip")
        end)

      assert has_updated_context,
             "Updated breadcrumb should contain '21Orbost Great Ocean Road Trip'"

      # Verify the old context name is no longer present in breadcrumbs
      has_old_context =
        Enum.any?(Map.values(updated_contexts), fn context ->
          context_name =
            case context do
              %{"name" => name} -> name
              name when is_binary(name) -> name
              _ -> ""
            end

          String.contains?(to_string(context_name), "Orbost Great Ocean Road Trip") and
            not String.contains?(to_string(context_name), "21Orbost Great Ocean Road Trip")
        end)

      refute has_old_context,
             "Updated breadcrumb should not contain old 'Orbost Great Ocean Road Trip'"

      # If we were to query breadcrumbs the way the UI does, we should see the updated name
      breadcrumb_trails = Query.query_album_breadcrumb_trails(orbost_album.id)

      breadcrumb_text =
        case breadcrumb_trails do
          [trail] when is_list(trail) ->
            # Extract icon names from the trail structure
            trail
            |> Enum.flat_map(fn {_position, icons} -> icons end)
            |> Enum.map(& &1.name)
            |> Enum.join(" 🠆 ")

          {:single_trail, trail} when is_list(trail) ->
            trail |> Enum.map(& &1.name) |> Enum.join(" 🠆 ")

          {:multiple_trails, trails} when is_list(trails) and length(trails) > 0 ->
            trails |> List.first() |> Enum.map(& &1.name) |> Enum.join(" 🠆 ")

          _ ->
            ""
        end

      assert String.contains?(breadcrumb_text, "21Orbost Great Ocean Road Trip"),
             "Breadcrumb should show updated context name. Got: #{breadcrumb_text}"

      refute String.contains?(breadcrumb_text, "Orbost Great Ocean Road Trip") and
               not String.contains?(breadcrumb_text, "21Orbost Great Ocean Road Trip"),
             "Breadcrumb should not show old context name. Got: #{breadcrumb_text}"
    end
  end
end
