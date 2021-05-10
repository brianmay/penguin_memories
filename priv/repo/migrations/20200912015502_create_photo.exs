defmodule PenguinMemories.Repo.Migrations.CreatePhoto do
  use Ecto.Migration

  def change do
    create table(:pm_photo) do
      add(:comment, :text)
      add(:rating, :float)
      add(:flash_used, :boolean)
      add(:metering_mode, :text)
      add(:datetime, :utc_datetime, null: false)
      add(:compression, :string)
      add(:title, :string)
      #add(:photographer_id, :integer)
      #add(:place_id, :integer)
      add(:aperture, :float)
      add(:ccd_width, :integer)
      add(:description, :string)
      add(:iso_equiv, :integer)
      add(:focal_length, :integer)
      add(:dir, :string, null: false)
      add(:exposure, :float)
      add(:name, :string, null: false)
      add(:level, :integer)
      add(:camera_make, :string)
      add(:camera_model, :string)
      add(:focus_dist, :float)
      add(:action, :string)
      add(:view, :string)
      add(:utc_offset, :integer, null: false)

      timestamps(type: :utc_datetime_usec)
    end

    create(index(:pm_photo, [:dir, :name], unique: true))
    create(index(:pm_photo, [:datetime]))
    create(index(:pm_photo, [:action]))
  end
end
