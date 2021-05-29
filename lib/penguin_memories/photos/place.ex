defmodule PenguinMemories.Photos.Place do
  @moduledoc "A location"
  use Ecto.Schema

  alias PenguinMemories.Photos.Photo
  alias PenguinMemories.Photos.PlaceAscendant

  @timestamps_opts [type: :utc_datetime]

  @type t :: %__MODULE__{
          id: integer() | nil,
          cover_photo_id: integer() | nil,
          cover_photo: Photo.t() | Ecto.Association.NotLoaded.t(),
          title: String.t() | nil,
          description: String.t() | nil,
          address: String.t() | nil,
          address2: String.t() | nil,
          city: String.t() | nil,
          state: String.t() | nil,
          postcode: String.t() | nil,
          country: String.t() | nil,
          url: String.t() | nil,
          private_notes: String.t() | nil,
          revised: DateTime.t() | nil,
          parent_id: integer() | nil,
          parent: t() | Ecto.Association.NotLoaded.t() | nil,
          children: list(t()) | Ecto.Association.NotLoaded.t(),
          ascendants: list(PlaceAscendant.t()) | Ecto.Association.NotLoaded.t(),
          descendants: list(PlaceAscendant.t()) | Ecto.Association.NotLoaded.t(),
          photos: list(Photo.t()) | Ecto.Association.NotLoaded.t(),
          inserted_at: DateTime.t() | nil,
          updated_at: DateTime.t() | nil
        }

  schema "pm_place" do
    belongs_to :cover_photo, Photo, on_replace: :nilify
    field :title, :string
    field :description, :string
    field :address, :string
    field :address2, :string
    field :city, :string
    field :state, :string
    field :postcode, :string
    field :country, :string
    field :url, :string
    field :private_notes, :string
    field :revised, :utc_datetime
    belongs_to :parent, PenguinMemories.Photos.Place, on_replace: :nilify
    has_many :children, PenguinMemories.Photos.Place, foreign_key: :parent_id
    has_many :ascendants, PenguinMemories.Photos.PlaceAscendant, foreign_key: :descendant_id
    has_many :descendants, PenguinMemories.Photos.PlaceAscendant, foreign_key: :ascendant_id
    has_many :photos, PenguinMemories.Photos.Photo, foreign_key: :place_id
    timestamps()
  end
end
