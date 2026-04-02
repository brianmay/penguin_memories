defmodule PenguinMemories.CircularReferenceCleanTest do
  use PenguinMemories.DataCase

  alias PenguinMemories.Database.Impl.Backend.Album
  alias PenguinMemories.Database.Query
  alias PenguinMemories.Photos.Album, as: AlbumSchema
  alias PenguinMemories.Repo

  describe "clean circular reference test" do
    test "validates without false positive circular reference errors" do
      # Create fresh albums each time
      {:ok, parent} = create_album("Clean Parent")
      {:ok, child} = create_album("Clean Child")

      IO.puts("\n=== CLEAN TEST: Circular reference validation ===")
      IO.puts("Parent ID: #{parent.id}, Child ID: #{child.id}")

      # Check ancestry before any relationships
      before_ancestor = Album.is_ancestor?(parent.id, child.id)
      before_reverse = Album.is_ancestor?(child.id, parent.id)
      IO.puts("is_ancestor?(#{parent.id}, #{child.id}): #{before_ancestor}")
      IO.puts("is_ancestor?(#{child.id}, #{parent.id}): #{before_reverse}")

      # Test 1: Validation should pass for new relationships (no circular reference)
      child_with_assoc = Repo.get!(AlbumSchema, child.id) |> Repo.preload([:album_parents])

      IO.puts(
        "Child's current album_parents: #{inspect(Enum.map(child_with_assoc.album_parents, & &1.parent_id))}"
      )

      params = %{"album_parents_edit" => [parent]}
      assoc = %{album_parents_edit: [parent]}

      changeset_before = Album.edit_changeset(child_with_assoc, params, assoc)
      IO.puts("Changeset before relationship exists - valid?: #{changeset_before.valid?}")

      IO.puts(
        "Changeset before relationship exists - errors: #{inspect(changeset_before.errors)}"
      )

      # Test 2: Apply the relationship via proper form save workflow
      {:ok, updated_child} = Query.apply_edit_changeset(changeset_before)

      IO.puts(
        "After form save - album_parents: #{inspect(Enum.map(updated_child.album_parents, & &1.parent_id))}"
      )

      # Test 3: Check ancestry after relationship is created
      after_ancestor = Album.is_ancestor?(parent.id, child.id)
      after_reverse = Album.is_ancestor?(child.id, parent.id)
      IO.puts("After relationship - is_ancestor?(#{parent.id}, #{child.id}): #{after_ancestor}")
      IO.puts("After relationship - is_ancestor?(#{child.id}, #{parent.id}): #{after_reverse}")

      # Test 4: Try changeset validation AFTER relationship exists (simulate UI case)
      child_with_existing = Repo.get!(AlbumSchema, child.id) |> Repo.preload([:album_parents])

      IO.puts(
        "Child's updated album_parents: #{inspect(Enum.map(child_with_existing.album_parents, & &1.parent_id))}"
      )

      changeset_after = Album.edit_changeset(child_with_existing, params, assoc)
      IO.puts("Changeset after relationship exists - valid?: #{changeset_after.valid?}")
      IO.puts("Changeset after relationship exists - errors: #{inspect(changeset_after.errors)}")

      # The core tests: both validation attempts should succeed (no false positives)
      assert changeset_before.valid?, "Expected changeset to be valid before relationship exists"

      assert changeset_after.valid?,
             "Expected changeset to be valid even after relationship exists (should be no-op)"

      # The relationship should be created after form save
      assert length(updated_child.album_parents) == 1,
             "Expected relationship to be created after form save"

      assert Enum.any?(updated_child.album_parents, &(&1.parent_id == parent.id)),
             "Expected specific parent relationship"
    end

    test "still detects actual circular references" do
      # Create albums for circular reference test
      {:ok, grandparent} = create_album("Grandparent")
      {:ok, parent} = create_album("Parent")
      {:ok, child} = create_album("Child")

      # First establish Grandparent -> Parent -> Child hierarchy
      child_parent_with_assoc =
        Repo.get!(AlbumSchema, parent.id) |> Repo.preload([:album_parents])

      params = %{"album_parents_edit" => [grandparent]}
      assoc = %{album_parents_edit: [grandparent]}
      changeset = Album.edit_changeset(child_parent_with_assoc, params, assoc)

      assert changeset.valid?, "Parent -> Grandparent relationship should be valid"
      {:ok, _} = Query.apply_edit_changeset(changeset)

      child_child_with_assoc = Repo.get!(AlbumSchema, child.id) |> Repo.preload([:album_parents])
      params = %{"album_parents_edit" => [parent]}
      assoc = %{album_parents_edit: [parent]}
      changeset = Album.edit_changeset(child_child_with_assoc, params, assoc)

      assert changeset.valid?, "Child -> Parent relationship should be valid"
      {:ok, _} = Query.apply_edit_changeset(changeset)

      # Now try to add Grandparent as direct parent of Child
      # This should fail because Grandparent is already ancestor of Child
      child_with_assoc = Repo.get!(AlbumSchema, child.id) |> Repo.preload([:album_parents])
      redundant_params = %{"album_parents_edit" => [parent, grandparent]}
      redundant_assoc = %{album_parents_edit: [parent, grandparent]}

      redundant_changeset =
        Album.edit_changeset(child_with_assoc, redundant_params, redundant_assoc)

      IO.puts("Circular reference test - valid?: #{redundant_changeset.valid?}")
      IO.puts("Circular reference test - errors: #{inspect(redundant_changeset.errors)}")

      # This should be detected as circular reference (redundant relationship prevention)
      refute redundant_changeset.valid?,
             "Adding Grandparent as direct parent should be invalid (redundant relationship)"

      assert Enum.any?(redundant_changeset.errors, fn {field, _} ->
               field == :album_parents_edit
             end),
             "Should have album_parents_edit error"
    end
  end

  defp create_album(name) do
    Repo.insert(%AlbumSchema{name: name, sort_name: String.downcase(name)})
  end
end
