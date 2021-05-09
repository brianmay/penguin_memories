defmodule PenguinMemories.Photos.Place do
  @moduledoc "An album containing photos and subalbums"
  use Ecto.Schema
  import Ecto.Changeset
  alias Ecto.Changeset

  import PenguinMemories.Photos.Private
  alias PenguinMemories.Photos.Photo
  alias PenguinMemories.Photos.PhotoPlace
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
          notes: String.t() | nil,
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

  schema "pm_album" do
    belongs_to :cover_photo, Photo
    field :title, :string
    field :description, :string
    field :address, :string
    field :address2, :string
    field :city, :string
    field :state, :string
    field :postcode, :string
    field :country, :string
    field :url, :string
    field :notes, :string
    field :revised, :utc_datetime
    belongs_to :parent, PenguinMemories.Photos.Place
    has_many :children, PenguinMemories.Photos.Place, foreign_key: :parent_id
    has_many :ascendants, PenguinMemories.Photos.PlaceAscendant, foreign_key: :descendant_id
    has_many :descendants, PenguinMemories.Photos.PlaceAscendant, foreign_key: :ascendant_id
    many_to_many :photos, PenguinMemories.Photos.Photo, join_through: PhotoPlace
    timestamps()
  end

  @spec validate_revised(Changeset.t()) :: Changeset.t()
  defp validate_revised(%Changeset{data: %__MODULE__{}} = changeset) do
    validate_pair(changeset, :revised, :revised_utc_offset)
  end

  @spec edit_changeset(t(), map()) :: Changeset.t()
  def edit_changeset(%__MODULE__{} = album, attrs) do
    album
    |> cast(attrs, [
      :cover_photo_id,
      :title,
      :description,
      :address,
      :address2,
      :city,
      :state,
      :postcode,
      :country,
      :url,
      :notes,
      :parent_id,
      :revised,
      :revised_utc_offset
    ])
    |> validate_required([:title])
    |> validate_revised()
  end

  @spec update_changeset(t(), MapSet.t(), map()) :: Changeset.t()
  def update_changeset(%__MODULE__{} = album, enabled, attrs) do
    allowed_list = [:title, :parent_id, :sort_name, :sort_order, :revised]
    allowed = MapSet.new(allowed_list)
    enabled = MapSet.intersection(enabled, allowed)
    enabled_list = MapSet.to_list(enabled)
    required = MapSet.new([:title, :sort_name, :sort_order])
    required_list = MapSet.to_list(MapSet.intersection(enabled, required))

    album
    |> cast(attrs, enabled_list)
    |> validate_required(required_list)
  end
end
