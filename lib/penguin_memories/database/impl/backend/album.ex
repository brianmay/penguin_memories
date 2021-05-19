defmodule PenguinMemories.Database.Impl.Backend.Album do
  @moduledoc """
  Backend Album functions
  """
  import Ecto.Query
  alias PenguinMemories.Database.Format
  alias PenguinMemories.Database.Impl.Backend.API
  alias PenguinMemories.Database.Query
  alias PenguinMemories.Database.Query.Details
  alias PenguinMemories.Database.Query.Field
  alias PenguinMemories.Photos.Album
  alias PenguinMemories.Photos.AlbumAscendant
  alias PenguinMemories.Photos.PhotoAlbum

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
  @spec get_title_from_result(result :: map()) :: String.t()
  def get_title_from_result(%{} = result) do
    "#{result.title}"
  end

  @impl API
  @spec get_subtitle_from_result(result :: map()) :: String.t()
  def get_subtitle_from_result(%{} = result) do
    "#{result.id}"
  end

  @impl API
  @spec get_details_from_result(
          result :: map(),
          icon_size :: String.t(),
          video_size :: String.t()
        ) :: Details.t()
  def get_details_from_result(%{} = result, icon_size, _video_size) do
    icon = Query.get_icon_from_result(result, Album)

    cover_photos =
      case result.o.cover_photo_id do
        nil -> nil
        id -> [Query.query_icon_by_id(id, PenguinMemories.Photos.Photo, "thumb")]
      end

    parent_icons =
      case result.o.parent_id do
        nil -> nil
        id -> [Query.query_icon_by_id(id, Album, icon_size)]
      end

    fields = [
      %Field{
        id: :title,
        title: "Title",
        display: result.o.title,
        type: :string
      },
      %Field{
        id: :parent_id,
        title: "Parent",
        display: nil,
        icons: parent_icons,
        type: :album
      },
      %Field{
        id: :description,
        title: "Description",
        display: result.o.description,
        type: :markdown
      },
      %Field{
        id: :private_notes,
        title: "Private Notes",
        display: result.o.private_notes,
        type: :markdown
      },
      %Field{
        id: :cover_photo_id,
        title: "Cover Photo",
        display: nil,
        icons: cover_photos,
        type: :photo
      },
      %Field{
        id: :revised,
        title: "Revised time",
        display: Format.display_datetime(result.o.revised),
        type: :datetime
      }
    ]

    cursor = Paginator.cursor_for_record(result, get_cursor_fields())

    %Details{
      obj: result.o,
      icon: icon,
      videos: [],
      fields: fields,
      cursor: cursor,
      type: Album
    }
  end

  @impl API
  @spec get_update_fields :: list(Field.t())
  def get_update_fields do
    [
      %Field{
        id: :title,
        title: "Title",
        display: nil,
        type: :string
      },
      %Field{
        id: :parent_id,
        title: "Parent",
        display: nil,
        type: :album
      },
      %Field{
        id: :revised,
        title: "Revised time",
        display: nil,
        type: :datetime
      }
    ]
  end
end
