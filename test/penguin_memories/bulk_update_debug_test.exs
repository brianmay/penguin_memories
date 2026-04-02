defmodule PenguinMemories.BulkUpdateDebugTest do
  use PenguinMemories.DataCase

  alias PenguinMemories.Database.Updates
  alias PenguinMemories.Photos.Album

  describe "bulk update debug" do
    test "reproduce actual bulk update issue with album_parents" do
      # Create test albums
      {:ok, child1} = Repo.insert(%Album{name: "Child 1", sort_name: "child 1"})
      {:ok, child2} = Repo.insert(%Album{name: "Child 2", sort_name: "child 2"})
      {:ok, parent} = Repo.insert(%Album{name: "Parent Album", sort_name: "parent album"})

      # Create a query that matches the albums with proper binding (similar to what the UI would do)
      query = from(o in Album, as: :object, where: o.id in [^child1.id, ^child2.id])

      # Create the update change exactly as the UI would
      update_change = %Updates.UpdateChange{
        field_id: :album_parents,
        change: :set,
        type: {:multiple, Album},
        value: [parent]
      }

      updates = [update_change]

      # This should reproduce the exact issue
      result = Updates.apply_updates(updates, query)

      case result do
        :ok ->
          IO.puts("Bulk update succeeded")

        {:error, reason} ->
          IO.puts("Bulk update failed with detailed error: #{reason}")
          flunk("Expected bulk update to work, got error: #{reason}")
      end
    end
  end
end
