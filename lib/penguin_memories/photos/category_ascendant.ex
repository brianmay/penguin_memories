defmodule PenguinMemories.Photos.CategoryAscendant do
  @moduledoc "Index for categorys"
  use Ecto.Schema
  import Ecto.Changeset
  @timestamps_opts [type: :utc_datetime]

  @type t :: %__MODULE__{
          id: integer() | nil,
          position: integer() | nil,
          ascendant_id: integer() | nil,
          ascendant: t() | nil,
          descendant_id: integer() | nil,
          descendant: t() | nil,
          inserted_at: DateTime.t() | nil,
          updated_at: DateTime.t() | nil
        }

  schema "pm_category_ascendant" do
    field :position, :integer
    belongs_to :ascendant, PenguinMemories.Photos.Category
    belongs_to :descendant, PenguinMemories.Photos.Category
    timestamps()
  end

  @doc false
  def changeset(category_ascendant, attrs) do
    category_ascendant
    |> cast(attrs, [:position])
    |> validate_required([:position])
  end
end
