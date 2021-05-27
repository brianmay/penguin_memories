defmodule PenguinMemories.Database.Impl.Backend.Category do
  @moduledoc """
  Backend Category functions
  """
  import Ecto.Query
  alias PenguinMemories.Database.Fields.Field
  alias PenguinMemories.Database.Fields.UpdateField
  alias PenguinMemories.Database.Impl.Backend.API
  alias PenguinMemories.Database.Query
  alias PenguinMemories.Photos.Category
  alias PenguinMemories.Photos.CategoryAscendant
  alias PenguinMemories.Photos.PhotoCategory
  alias PenguinMemories.Repo

  @behaviour API

  @impl API
  @spec get_single_name :: String.t()
  def get_single_name, do: "category"

  @impl API
  @spec get_plural_name :: String.t()
  def get_plural_name, do: "categories"

  @impl API
  @spec get_cursor_fields :: list(atom())
  def get_cursor_fields, do: [:title, :id]

  @impl API
  @spec get_parent_fields :: list(atom())
  def get_parent_fields, do: [:parent_id]

  @impl API
  @spec get_index_type :: module() | nil
  def get_index_type, do: CategoryAscendant

  @impl API
  @spec query :: Ecto.Query.t()
  def query do
    from o in Category,
      as: :object,
      select: %{title: o.title, id: o.id},
      order_by: [asc: o.title, asc: o.id]
  end

  @impl API
  @spec filter_by_photo_id(query :: Ecto.Query.t(), photo_id :: integer) :: Ecto.Query.t()
  def filter_by_photo_id(%Ecto.Query{} = query, photo_id) do
    from [object: o] in query,
      join: op in PhotoCategory,
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
  def filter_by_reference(%Ecto.Query{} = query, {Category, id}) do
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
    icon = Query.get_icon_from_result(result, Category)
    cursor = Paginator.cursor_for_record(result, get_cursor_fields())

    %Query.Details{
      obj: result.o,
      icon: icon,
      videos: [],
      cursor: cursor,
      type: Category
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
        type: {:single, Category}
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
        type: {:single, Category},
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
end
