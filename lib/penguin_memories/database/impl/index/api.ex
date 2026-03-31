defmodule PenguinMemories.Database.Impl.Index.API do
  @moduledoc """
  API used for indexing.
  """
  @type object_type :: PenguinMemories.Database.object_type()

  @callback get_parent_ids(integer, object_type) :: list(integer())
  @callback get_child_ids(integer, object_type) :: list(integer())
  @callback get_index(integer, object_type) :: MapSet.t()
  @callback bulk_update_index(
              id :: integer,
              to_delete :: list(integer()),
              to_upsert :: list({integer(), integer()}),
              type :: object_type
            ) :: :ok
  @callback set_done(integer, object_type) :: :ok
end
