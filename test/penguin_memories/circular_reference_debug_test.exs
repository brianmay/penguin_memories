defmodule PenguinMemories.CircularReferenceDebugTest do
  use PenguinMemories.DataCase

  alias PenguinMemories.Database.Impl.Backend.Album
  alias PenguinMemories.Photos.Album, as: AlbumSchema
  alias PenguinMemories.Repo

  describe "circular reference validation debugging" do
    setup do
      # Create test albums similar to the real scenario
      {:ok, album1} = create_album("Parent1")
      {:ok, album40} = create_album("Album 40")
      {:ok, album41} = create_album("Album 41")

      %{album1: album1, album40: album40, album41: album41}
    end

    test "reproduces false circular reference error from UI", %{album1: album1, album40: album40} do
      # Test the exact scenario that's causing issues
      IO.puts("\n=== CIRCULAR REFERENCE DEBUG TEST ===")

      IO.puts(
        "Attempting to add Album #{album1.id} (#{album1.name}) as parent of Album #{album40.id} (#{album40.name})"
      )

      # First, verify this should be allowed by backend
      result = Album.add_to_parent(album40.id, album1.id, %{})
      IO.puts("Backend add_to_parent result: #{inspect(result)}")

      # Now test the changeset validation used by UI
      # This simulates what happens in handle_album_parents_assoc
      album_parents_data = [%{id: album1.id, name: album1.name}]

      # Get album with current relationships
      album_with_assoc = Repo.get!(AlbumSchema, album40.id) |> Repo.preload([:album_parents])
      IO.puts("Current album_parents: #{inspect(album_with_assoc.album_parents)}")

      # Test the changeset logic through the public API
      # This simulates what the UI does when editing album_parents_edit
      import Ecto.Changeset

      # Simulate what the UI form does - pass album_parents_edit in params  
      params = %{"album_parents_edit" => [album1]}
      assoc = %{album_parents_edit: [album1]}

      # Apply the edit_changeset which includes our custom logic
      final_changeset = Album.edit_changeset(album_with_assoc, params, assoc)
      IO.puts("Final changeset valid?: #{final_changeset.valid?}")
      IO.puts("Final changeset errors: #{inspect(final_changeset.errors)}")

      # Test is_ancestor? directly to verify the logic
      ancestor_check = Album.is_ancestor?(album1.id, album40.id)
      IO.puts("is_ancestor?(#{album1.id}, #{album40.id}): #{ancestor_check}")

      reverse_check = Album.is_ancestor?(album40.id, album1.id)
      IO.puts("is_ancestor?(#{album40.id}, #{album1.id}): #{reverse_check}")

      # Test should pass - no circular reference should be detected
      assert final_changeset.valid?,
             "Expected changeset to be valid but got errors: #{inspect(final_changeset.errors)}"
    end

    test "verify circular reference detection works for actual circles", %{
      album1: album1,
      album40: album40
    } do
      # First establish album40 -> album1 relationship  
      {:ok, _} = Album.add_to_parent(album40.id, album1.id, %{})

      # Now try to add album40 as parent of album1 (this SHOULD fail)
      result = Album.add_to_parent(album1.id, album40.id, %{})
      IO.puts("Expected circular reference error: #{inspect(result)}")

      # This should detect circular reference
      assert result == {:error, :circular_reference}
    end
  end

  defp create_album(name) do
    Repo.insert(%AlbumSchema{name: name, sort_name: String.downcase(name)})
  end
end
