defmodule PenguinMemories.Database.Impl.Backend.AlbumParent do
  @moduledoc """
  Backend AlbumParent functions for many-to-many album relationships with context
  """
  import Ecto.Query

  alias PenguinMemories.Database.Fields.Field
  alias PenguinMemories.Database.Fields.UpdateField
  alias PenguinMemories.Database.Impl.Backend.API
  alias PenguinMemories.Database.Query
  alias PenguinMemories.Photos.Album
  alias PenguinMemories.Photos.AlbumParent
  alias PenguinMemories.Repo

  @behaviour API

  @impl API
  def get_single_name, do: "Album Parent"

  @impl API
  def get_plural_name, do: "Album Parents"

  @impl API
  def get_cursor_fields, do: [:id]

  @impl API
  def get_parent_fields, do: []

  @impl API
  def get_parent_id_fields, do: []

  @impl API
  def get_index_type, do: nil

  @impl API
  def query do
    from o in AlbumParent,
      as: :object,
      select: %{
        id: o.id,
        album_id: o.album_id,
        parent_id: o.parent_id,
        context_name: o.context_name,
        context_sort_name: o.context_sort_name
      },
      order_by: [asc: o.context_sort_name, asc: o.context_name, asc: o.id]
  end

  @impl API
  def filter_by_photo_id(%Ecto.Query{} = query, _photo_id) do
    # AlbumParent doesn't directly relate to photos
    query
  end

  @impl API
  def filter_by_parent_id(%Ecto.Query{} = query, parent_id) do
    from [object: o] in query, where: o.parent_id == ^parent_id
  end

  @impl API
  def filter_by_reference(%Ecto.Query{} = query, {Album, id}, _deep) do
    from [object: o] in query, where: o.album_id == ^id or o.parent_id == ^id
  end

  def filter_by_reference(%Ecto.Query{} = query, _, _deep) do
    query
  end

  @impl API
  def preload_details(query) do
    preload(query, [:album, :parent])
  end

  @impl API
  def preload_details_from_results(results) do
    Repo.preload(results, [:album, :parent])
  end

  @impl API
  def get_title_from_result(result) do
    result[:context_name] || "Album Parent #{result[:id]}"
  end

  @impl API
  def get_subtitle_from_result(result) do
    result[:context_sort_name]
  end

  @impl API
  def get_icon_details_from_result(_result) do
    nil
  end

  @impl API
  def get_details_from_result(result, _icon_size, _video_size) do
    cursor = Paginator.cursor_for_record(result, get_cursor_fields())

    obj = %AlbumParent{
      id: result.id,
      album_id: result.album_id,
      parent_id: result.parent_id,
      context_name: result.context_name,
      context_sort_name: result.context_sort_name
    }

    %Query.Details{
      obj: obj,
      icon: nil,
      orig: nil,
      raw: nil,
      videos: [],
      cursor: cursor,
      type: AlbumParent
    }
  end

  @impl API
  def get_fields do
    [
      %Field{
        id: :id,
        name: "ID",
        type: :integer,
        read_only: true,
        searchable: true
      },
      %Field{
        id: :context_name,
        name: "Context Name",
        type: :string,
        searchable: true
      },
      %Field{
        id: :context_sort_name,
        name: "Context Sort Name",
        type: :string,
        searchable: true
      },
      %Field{
        id: :album,
        name: "Album",
        type: {:single, Album},
        searchable: true
      },
      %Field{
        id: :parent,
        name: "Parent",
        type: {:single, Album},
        searchable: true
      }
    ]
  end

  @impl API
  def get_update_fields do
    [
      %UpdateField{
        id: :context_name,
        field_id: :context_name,
        name: "Context Name",
        type: :string,
        change: :set
      },
      %UpdateField{
        id: :context_sort_name,
        field_id: :context_sort_name,
        name: "Context Sort Name",
        type: :string,
        change: :set
      }
    ]
  end

  @impl API
  def edit_changeset(%AlbumParent{} = object, attrs, _assoc) do
    object
    |> Ecto.Changeset.cast(attrs, [:context_name, :context_sort_name])
    |> Ecto.Changeset.validate_required([:album_id, :parent_id])
  end

  @impl API
  def update_changeset(attrs, _assoc, _enabled) do
    # Simple changeset for bulk updates
    %AlbumParent{}
    |> Ecto.Changeset.cast(attrs, [:context_name, :context_sort_name])
  end
end
