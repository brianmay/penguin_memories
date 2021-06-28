defmodule PenguinMemories.Database.Impl.Index.API do
  @moduledoc """
  API used for indexing.
  """
  @type object_type :: PenguinMemories.Database.object_type()

  @callback get_parent_ids(integer, object_type) :: list(integer())
  @callback get_child_ids(integer, object_type) :: list(integer())
  @callback get_index(integer, object_type) :: MapSet.t()
  @callback create_index(integer, {integer, integer}, object_type) :: :ok
  @callback update_index(integer, {integer, integer}, object_type) :: :ok
  @callback delete_index(integer, integer, object_type) :: :ok
  @callback set_done(integer, object_type) :: :ok
end
