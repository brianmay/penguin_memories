defmodule PenguinMemories.Repo.Migrations.CreatePersons do
  use Ecto.Migration

  def change do
    create table(:pm_person) do
      add(:cover_photo_id, references(:pm_photo, on_delete: :nilify_all))
      add(:name, :text, null: false)
      add(:called, :text)
      add(:sort_name, :text, null: false)
      add(:date_of_birth, :date)
      add(:date_of_death, :date)
      add(:home_id, references(:pm_place, on_delete: :nilify_all))
      add(:work_id, references(:pm_place, on_delete: :nilify_all))
      add(:father_id, references(:pm_person, on_delete: :nilify_all))
      add(:mother_id, references(:pm_person, on_delete: :nilify_all))
      add(:spouse_id, references(:pm_person, on_delete: :nilify_all))
      add(:description, :text)
      add(:private_notes, :text)
      add(:email, :text)
      add(:revised, :utc_datetime)
      add(:parent_id, references(:pm_person, on_delete: :nilify_all))

      timestamps(type: :utc_datetime_usec)
    end

    create(index(:pm_person, [:cover_photo_id]))
    create(index(:pm_person, [:name]))
    create(index(:pm_person, [:sort_name, :name, :id]))
    create(index(:pm_person, [:revised]))
    create(index(:pm_person, [:home_id]))
    create(index(:pm_person, [:work_id]))
    create(index(:pm_person, [:father_id]))
    create(index(:pm_person, [:mother_id]))
    create(index(:pm_person, [:spouse_id]))

    create table(:pm_photo_person) do
      add(:photo_id, references(:pm_photo, on_delete: :delete_all), null: false)
      add(:person_id, references(:pm_person, on_delete: :delete_all), null: false)
      add(:position, :integer, null: false)

      timestamps(type: :utc_datetime_usec)
    end

    create(index(:pm_photo_person, [:photo_id, :person_id], unique: true))
    create(index(:pm_photo_person, [:photo_id, :position], unique: true))
    create(index(:pm_photo_person, [:person_id]))

    create table(:pm_person_ascendant) do
      add(:position, :integer, null: false)
      add(:ascendant_id, references(:pm_person, on_delete: :delete_all), null: false)
      add(:descendant_id, references(:pm_person, on_delete: :delete_all), null: false)

      timestamps(type: :utc_datetime_usec)
    end

    create(index(:pm_person_ascendant, [:ascendant_id, :descendant_id], unique: true))
    create(index(:pm_person_ascendant, [:descendant_id]))
  end
end
