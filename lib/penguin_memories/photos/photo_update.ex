defmodule PenguinMemories.Photos.PhotoUpdate do
  @moduledoc "An update to a photo"
  use Ecto.Schema

  alias PenguinMemories.Photos.Album
  alias PenguinMemories.Photos.Category
  alias PenguinMemories.Photos.Person
  alias PenguinMemories.Photos.PhotoAlbum
  alias PenguinMemories.Photos.PhotoCategory
  alias PenguinMemories.Photos.Place

  @timestamps_opts [type: :utc_datetime_usec]

  @type t :: %__MODULE__{
          name: String.t() | nil,
          photographer: Person.t() | Ecto.Association.NotLoaded.t() | nil,
          place: Place.t() | Ecto.Association.NotLoaded.t() | nil,
          album_add: list(Album.t()) | Ecto.Association.NotLoaded.t() | nil,
          album_delete: list(Album.t()) | Ecto.Association.NotLoaded.t() | nil,
          category_add: list(Category.t()) | Ecto.Association.NotLoaded.t() | nil,
          category_delete: list(Category.t()) | Ecto.Association.NotLoaded.t() | nil,
          view: String.t() | nil,
          rating: float | nil,
          datetime: DateTime.t() | nil,
          utc_offset: integer() | nil,
          action: String.t() | nil
        }

  embedded_schema do
    field :name, :string
    belongs_to :photographer, Person, on_replace: :nilify
    belongs_to :place, Place, on_replace: :nilify
    many_to_many :album_add, Album, join_through: PhotoAlbum, on_replace: :delete
    many_to_many :album_delete, Album, join_through: PhotoAlbum, on_replace: :delete
    many_to_many :category_add, Category, join_through: PhotoCategory, on_replace: :delete
    many_to_many :category_delete, Category, join_through: PhotoCategory, on_replace: :delete
    field :view, :string
    field :rating, :float
    field :datetime, :utc_datetime
    field :utc_offset, :integer
    field :action, :string
  end
end
