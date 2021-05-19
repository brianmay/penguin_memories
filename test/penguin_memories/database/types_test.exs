defmodule PenguinMemories.Database.TypesTest do
  use ExUnit.Case, async: true

  alias PenguinMemories.Database.Types

  test "get_type_by_name/1" do
    assert Types.get_type_for_name("album") == {:ok, PenguinMemories.Photos.Album}
    assert Types.get_type_for_name("category") == {:ok, PenguinMemories.Photos.Category}
    assert Types.get_type_for_name("place") == {:ok, PenguinMemories.Photos.Place}
    assert Types.get_type_for_name("person") == {:ok, PenguinMemories.Photos.Person}
    assert Types.get_type_for_name("photo") == {:ok, PenguinMemories.Photos.Photo}
  end

  test "get_name_by_type/1" do
    assert Types.get_name!(PenguinMemories.Photos.Album) == "album"
    assert Types.get_name!(PenguinMemories.Photos.Category) == "category"
    assert Types.get_name!(PenguinMemories.Photos.Place) == "place"
    assert Types.get_name!(PenguinMemories.Photos.Person) == "person"
    assert Types.get_name!(PenguinMemories.Photos.Photo) == "photo"
  end
end
