defmodule PenguinMemories.Database do
  @moduledoc """
  Database functions
  """
  @type object_type ::
          PenguinMemories.Photos.Album
          | PenguinMemories.Photos.Category
          | PenguinMemories.Photos.Person
          | PenguinMemories.Photos.Place
          | PenguinMemories.Photos.Photo
  @type reference_type :: {object_type(), integer()}
end
