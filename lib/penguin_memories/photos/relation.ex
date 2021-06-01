defmodule PenguinMemories.Photos.Relation do
  @moduledoc "An album containing photos and subalbums"
  use Ecto.Schema
  # import Ecto.Changeset
  # alias Ecto.Changeset

  @timestamps_opts [type: :utc_datetime]

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

  # @spec edit_changeset(t(), map()) :: Changeset.t()
  # def edit_changeset(%__MODULE__{} = album, attrs) do
  #   album
  #   |> cast(attrs, [
  #     :name,
  #     :description
  #   ])
  #   |> validate_required([:name])
  # end

  # @spec update_changeset(t(), MapSet.t(), map()) :: Changeset.t()
  # def update_changeset(%__MODULE__{} = album, enabled, attrs) do
  #   allowed_list = [:name, :description]
  #   allowed = MapSet.new(allowed_list)
  #   enabled = MapSet.intersection(enabled, allowed)
  #   enabled_list = MapSet.to_list(enabled)
  #   required = MapSet.new([:name])
  #   required_list = MapSet.to_list(MapSet.intersection(enabled, required))

  #   album
  #   |> cast(attrs, enabled_list)
  #   |> validate_required(required_list)
  # end
end
