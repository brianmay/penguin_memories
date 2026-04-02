defmodule PenguinMemories.Database.Impl.Index.AlbumAware do
  @moduledoc """
  Index API that handles albums with many-to-many parent relationships.
  Delegates to Generic for other types.
  """
  import Ecto.Query

  alias PenguinMemories.Database.Impl.Index.API
  alias PenguinMemories.Database.Impl.Index.Generic
  alias PenguinMemories.Photos.Album
  alias PenguinMemories.Photos.AlbumParent
  alias PenguinMemories.Repo

  @behaviour API

  @impl API
  @spec get_parent_ids(id :: integer, type :: module) :: list(integer())
  def get_parent_ids(id, Album) do
    # For albums, get parents from both old parent_id field AND new AlbumParent table
    album = Repo.get!(Album, id)

    # Get old-style parent
    old_parent_ids = if album.parent_id, do: [album.parent_id], else: []

    # Get new many-to-many parents
    new_parent_ids =
      from(ap in AlbumParent,
        where: ap.album_id == ^id,
        select: ap.parent_id
      )
      |> Repo.all()

    # Combine and deduplicate
    (old_parent_ids ++ new_parent_ids)
    |> Enum.uniq()
  end

  def get_parent_ids(id, type) do
    # Delegate to generic implementation for other types
    Generic.get_parent_ids(id, type)
  end

  @impl API
  @spec get_child_ids(id :: integer, type :: module) :: list(integer())
  def get_child_ids(id, Album) do
    # For albums, get children from both old parent_id field AND new AlbumParent table

    # Get old-style children
    old_child_ids =
      from(a in Album,
        where: a.parent_id == ^id,
        select: a.id
      )
      |> Repo.all()

    # Get new many-to-many children  
    new_child_ids =
      from(ap in AlbumParent,
        where: ap.parent_id == ^id,
        select: ap.album_id
      )
      |> Repo.all()

    # Combine and deduplicate
    (old_child_ids ++ new_child_ids)
    |> Enum.uniq()
  end

  def get_child_ids(id, type) do
    # Delegate to generic implementation for other types
    Generic.get_child_ids(id, type)
  end

  # Delegate all other functions to Generic
  @impl API
  defdelegate get_index(id, type), to: Generic

  @impl API
  defdelegate bulk_update_index(id, to_delete, to_upsert, type), to: Generic

  @impl API
  defdelegate set_done(id, type), to: Generic
end
