defmodule PenguinMemories.Repo.Migrations.CreatePlaces do
  use Ecto.Migration

  def change do
    create table(:pm_place) do
      add(:cover_photo_id, references(:pm_photo, on_delete: :nilify_all))
      add(:name, :text, null: false)
      add(:description, :text)
      add(:address, :text)
      add(:address2, :text)
      add(:city, :text)
      add(:state, :text)
      add(:postcode, :text)
      add(:country, :text)
      add(:url, :text)
      add(:private_notes, :text)

      add(:revised, :utc_datetime)
      add(:parent_id, references(:pm_place, on_delete: :nilify_all))

      timestamps(type: :utc_datetime_usec)
    end

    create(index(:pm_place, [:cover_photo_id]))
    create(index(:pm_place, [:name, :id]))
    create(index(:pm_place, [:revised]))
    create(index(:pm_place, [:parent_id]))

    # create table(:pm_photo_place) do
    #   add(:photo_id, references(:pm_photo, on_delete: :delete_all), null: false)
    #   add(:place_id, references(:pm_place, on_delete: :delete_all), null: false)

    #   timestamps(type: :utc_datetime_usec)
    # end

    # create(index(:pm_photo_place, [:photo_id, :place_id], unique: true))
    # create(index(:pm_photo_place, [:place_id]))

    create table(:pm_place_ascendant) do
      add(:position, :integer, null: false)
      add(:ascendant_id, references(:pm_place, on_delete: :delete_all), null: false)
      add(:descendant_id, references(:pm_place, on_delete: :delete_all), null: false)

      timestamps(type: :utc_datetime_usec)
    end

    create(index(:pm_place_ascendant, [:ascendant_id, :descendant_id], unique: true))
    create(index(:pm_place_ascendant, [:descendant_id]))
  end
end
