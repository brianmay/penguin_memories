defmodule PenguinMemories.Database.Impl.Backend.Album do
  @moduledoc """
  Backend Album functions
  """
  alias Ecto.Changeset
  import Ecto.Changeset
  import Ecto.Query

  alias PenguinMemories.Database.Fields.Field
  alias PenguinMemories.Database.Fields.UpdateField
  alias PenguinMemories.Database.Impl.Backend.API
  alias PenguinMemories.Database.Impl.Backend.Private
  alias PenguinMemories.Database.Query
  alias PenguinMemories.Photos.Album
  alias PenguinMemories.Photos.AlbumAscendant
  alias PenguinMemories.Photos.PhotoAlbum
  alias PenguinMemories.Repo

  @behaviour API

  @impl API
  @spec get_single_name :: String.t()
  def get_single_name, do: "album"

  @impl API
  @spec get_plural_name :: String.t()
  def get_plural_name, do: "albums"

  @impl API
  @spec get_cursor_fields :: list(atom())
  def get_cursor_fields, do: [:title, :id]

  @impl API
  @spec get_parent_fields :: list(atom())
  def get_parent_fields, do: [:parent_id]

  @impl API
  @spec get_index_type :: module() | nil
  def get_index_type, do: AlbumAscendant

  @impl API
  @spec query :: Ecto.Query.t()
  def query do
    from o in Album,
      as: :object,
      select: %{title: o.title, id: o.id},
      order_by: [asc: o.title, asc: o.id]
  end

  @impl API
  @spec filter_by_photo_id(query :: Ecto.Query.t(), photo_id :: integer) :: Ecto.Query.t()
  def filter_by_photo_id(%Ecto.Query{} = query, photo_id) do
    from [object: o] in query,
      join: op in PhotoAlbum,
      on: op.album_id == o.id,
      where: op.photo_id == ^photo_id
  end

  @impl API
  @spec filter_by_parent_id(query :: Ecto.Query.t(), parent_id :: integer) :: Ecto.Query.t()
  def filter_by_parent_id(%Ecto.Query{} = query, parent_id) do
    from [object: o] in query, where: o.parent_id == ^parent_id
  end

  @impl API
  @spec filter_by_reference(query :: Ecto.Query.t(), reference :: {module(), integer()}) ::
          Ecto.Query.t()
  def filter_by_reference(%Ecto.Query{} = query, {Album, id}) do
    filter_by_parent_id(query, id)
  end

  def filter_by_reference(%Ecto.Query{} = query, _) do
    query
  end

  @impl API
  @spec preload_details(query :: Ecto.Query.t()) :: Ecto.Query.t()
  def preload_details(query) do
    preload(query, [:cover_photo, :parent])
  end

  @impl API
  @spec preload_details_from_results(results :: list(struct())) :: list(struct())
  def preload_details_from_results(results) do
    Repo.preload(results, [:cover_photo, :parent])
  end

  @impl API
  @spec get_title_from_result(result :: map()) :: String.t()
  def get_title_from_result(%{} = result) do
    "#{result.title}"
  end

  @impl API
  @spec get_subtitle_from_result(result :: map()) :: String.t() | nil
  def get_subtitle_from_result(%{} = _result) do
    nil
  end

  @impl API
  @spec get_details_from_result(
          result :: map(),
          icon_size :: String.t(),
          video_size :: String.t()
        ) :: Query.Details.t()
  def get_details_from_result(%{} = result, _icon_size, _video_size) do
    icon = Query.get_icon_from_result(result, Album)
    cursor = Paginator.cursor_for_record(result, get_cursor_fields())

    %Query.Details{
      obj: result.o,
      icon: icon,
      videos: [],
      cursor: cursor,
      type: Album
    }
  end

  @impl API
  @spec get_fields :: list(Field.t())
  def get_fields do
    [
      %Field{
        id: :title,
        title: "Title",
        type: :string
      },
      %Field{
        id: :parent,
        title: "Parent",
        type: {:single, Album}
      },
      %Field{
        id: :description,
        title: "Description",
        type: :markdown
      },
      %Field{
        id: :private_notes,
        title: "Private Notes",
        type: :markdown,
        access: :private
      },
      %Field{
        id: :cover_photo,
        title: "Cover Photo",
        type: {:single, PenguinMemories.Photos.Photo}
      },
      %Field{
        id: :revised,
        title: "Revised time",
        type: :datetime
      }
    ]
  end

  @impl API
  @spec get_update_fields :: list(UpdateField.t())
  def get_update_fields do
    [
      %UpdateField{
        id: :title,
        field_id: :title,
        title: "Title",
        type: :string,
        change: :set
      },
      %UpdateField{
        id: :parent,
        field_id: :parent,
        title: "Parent",
        type: {:single, Album},
        change: :set
      },
      %UpdateField{
        id: :revised,
        field_id: :revised,
        title: "Revised time",
        type: :datetime,
        change: :set
      }
    ]
  end

  @impl API
  @spec edit_changeset(object :: Album.t(), attrs :: map(), assoc :: map()) :: Changeset.t()
  def edit_changeset(%Album{} = object, attrs, assoc) do
    object
    |> cast(attrs, [
      :title,
      :description,
      :private_notes,
      :revised
    ])
    |> validate_required([:title])
    |> Private.put_all_assoc(assoc, [:parent, :cover_photo])
  end

  @impl API
  @spec update_changeset(
          object :: Album.t(),
          attrs :: map(),
          assoc :: map(),
          enabled :: MapSet.t()
        ) ::
          Changeset.t()
  def update_changeset(%Album{} = object, attrs, assoc, enabled) do
    object
    |> Private.selective_cast(attrs, enabled, [:title, :revised])
    |> Private.selective_validate_required(enabled, [:title])
    |> Private.selective_put_assoc(assoc, enabled, [:parent, :cover_photo])
  end
end
