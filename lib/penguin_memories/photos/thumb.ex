defmodule PenguinMemories.Photos.Thumb do
  use Ecto.Schema
  import Ecto.Changeset

  schema "spud_photo_thumb" do
    field :height, :integer
    field :size, :string
    field :width, :integer
    belongs_to :photo, Photo
  end

  @doc false
  def changeset(thumb, attrs) do
    thumb
    |> cast(attrs, [:height, :width, :size])
    |> validate_required([:height, :width, :size])
  end
end
