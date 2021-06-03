defmodule PenguinMemories.Photos.Relation do
  @moduledoc "An album containing photos and subalbums"
  use Ecto.Schema
  # import Ecto.Changeset
  # alias Ecto.Changeset

  @timestamps_opts [type: :utc_datetime_usec]

  @type t :: %__MODULE__{
          id: integer() | nil,
          name: String.t() | nil,
          description: String.t() | nil,
          inserted_at: DateTime.t() | nil,
          updated_at: DateTime.t() | nil
        }

  schema "pm_relation" do
    field :name, :string
    field :description, :string
    timestamps()
  end
end
