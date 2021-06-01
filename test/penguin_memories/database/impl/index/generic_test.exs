defmodule PenguinMemories.Database.Impl.Index.GenericTest do
  use ExUnit.Case, async: true
  use PenguinMemories.DataCase

  require Assertions
  import Assertions

  alias PenguinMemories.Database.Impl.Index.Generic
  alias PenguinMemories.Database.Types
  alias PenguinMemories.Photos.Album
  alias PenguinMemories.Photos.Category
  alias PenguinMemories.Photos.Person
  alias PenguinMemories.Photos.Photo
  alias PenguinMemories.Photos.Place

  @spec create(module(), String.t(), keyword()) :: struct()
  defp create(module, name, opts \\ [])

  defp create(Person = module, name, opts) do
    opts = Keyword.put(opts, :name, name)
    opts = Keyword.put(opts, :sort_name, name)
    struct(module, opts) |> Repo.insert!()
  end

  defp create(Photo = module, name, opts) do
    datetime = ~U[2000-01-01 12:00:00Z]
    opts = Keyword.put(opts, :name, name)
    opts = Keyword.put_new(opts, :datetime, datetime)
    opts = Keyword.put_new(opts, :utc_offset, 0)
    opts = Keyword.put_new(opts, :dir, "a")
    opts = Keyword.put_new(opts, :filename, "a.jpg")
    struct(module, opts) |> Repo.insert!()
  end

  defp create(module, name, opts) do
    opts = Keyword.put(opts, :name, name)
    struct(module, opts) |> Repo.insert!()
  end

  describe "get_parent_ids/2" do
    test "album" do
      parent = create(Album, "parent")
      child = create(Album, "child", parent_id: parent.id)
      parents = Generic.get_parent_ids(child.id, Album)
      assert_lists_equal(parents, [parent.id])
    end

    test "category" do
      parent = create(Category, "parent")
      child = create(Category, "child", parent_id: parent.id)
      parents = Generic.get_parent_ids(child.id, Category)
      assert_lists_equal(parents, [parent.id])
    end

    test "person" do
      mother = create(Person, "mother")
      father = create(Person, "father")
      child = create(Person, "child", mother_id: mother.id, father_id: father.id)
      parents = Generic.get_parent_ids(child.id, Person)
      assert_lists_equal(parents, [mother.id, father.id])
    end

    test "place" do
      parent = create(Place, "parent")
      child = create(Place, "child", parent_id: parent.id)
      parents = Generic.get_parent_ids(child.id, Place)
      assert_lists_equal(parents, [parent.id])
    end

    test "photo" do
      child = create(Photo, "child")
      parents = Generic.get_parent_ids(child.id, Photo)
      assert_lists_equal(parents, [])
    end
  end

  describe "get_child_ids/2" do
    test "album" do
      parent = create(Album, "parent")
      child1 = create(Album, "child1", parent_id: parent.id)
      child2 = create(Album, "child2", parent_id: parent.id)
      children = Generic.get_child_ids(parent.id, Album)
      assert_lists_equal(children, [child1.id, child2.id])
    end

    test "category" do
      parent = create(Category, "parent")
      child1 = create(Category, "child1", parent_id: parent.id)
      child2 = create(Category, "child2", parent_id: parent.id)
      children = Generic.get_child_ids(parent.id, Category)
      assert_lists_equal(children, [child1.id, child2.id])
    end

    test "person" do
      mother = create(Person, "mother")
      father = create(Person, "father")
      child1 = create(Person, "child1", mother_id: mother.id, father_id: father.id)
      child2 = create(Person, "child2", mother_id: mother.id, father_id: father.id)
      children = Generic.get_child_ids(mother.id, Person)
      assert_lists_equal(children, [child1.id, child2.id])
      children = Generic.get_child_ids(father.id, Person)
      assert_lists_equal(children, [child1.id, child2.id])
    end

    test "place" do
      parent = create(Place, "parent")
      child1 = create(Place, "child1", parent_id: parent.id)
      child2 = create(Place, "child2", parent_id: parent.id)
      children = Generic.get_child_ids(parent.id, Place)
      assert_lists_equal(children, [child1.id, child2.id])
    end

    test "photo" do
      parent = create(Photo, "child")
      children = Generic.get_child_ids(parent.id, Photo)
      assert_lists_equal(children, [])
    end
  end

  describe "get_index/2" do
    for type <- [Album, Category, Person, Place] do
      @tag type: type
      test "#{inspect(type)}", %{type: type} do
        index = Types.get_backend!(type).get_index_type()
        obj = create(type, "object")
        struct(index, ascendant_id: obj.id, descendant_id: obj.id, position: 0) |> Repo.insert!()
        result = Generic.get_index(obj.id, type)
        assert result == MapSet.new([{obj.id, 0}])
      end
    end
  end

  describe "create_index/3" do
    for type <- [Album, Category, Person, Place] do
      @tag type: type
      test "#{inspect(type)}", %{type: type} do
        obj = create(type, "object")
        :ok = Generic.create_index(obj.id, {obj.id, 0}, type)
        result = Generic.get_index(obj.id, type)
        assert result == MapSet.new([{obj.id, 0}])
      end
    end
  end

  describe "delete_index/3" do
    for type <- [Album, Category, Person, Place] do
      @tag type: type
      test "#{inspect(type)}", %{type: type} do
        index = Types.get_backend!(type).get_index_type()
        obj = create(type, "object")
        struct(index, ascendant_id: obj.id, descendant_id: obj.id, position: 0) |> Repo.insert!()
        :ok = Generic.delete_index(obj.id, {obj.id, 999}, type)
        result = Generic.get_index(obj.id, type)
        assert result == MapSet.new([])
      end
    end
  end
end
