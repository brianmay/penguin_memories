defmodule PenguinMemories.Database.API do
  @moduledoc """
  Generic database functions
  """
  @type object_type ::
          PenguinMemories.Photos.Album
          | PenguinMemories.Photos.Category
          | PenguinMemories.Photos.Person
          | PenguinMemories.Photos.Place
          | PenguinMemories.Photos.Photo

  @callback get_parent_ids(integer, object_type) :: list(integer())
  @callback get_child_ids(integer, object_type) :: list(integer())
  @callback get_index(integer, object_type) :: MapSet.t()
  @callback create_index(integer, {integer, integer}, object_type) :: :ok
  @callback delete_index(integer, {integer, integer}, object_type) :: :ok
end
