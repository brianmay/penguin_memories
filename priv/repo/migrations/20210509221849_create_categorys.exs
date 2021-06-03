defmodule PenguinMemories.Repo.Migrations.CreateCategorys do
  use Ecto.Migration

  def change do
    create table(:pm_category) do
      add(:cover_photo_id, references(:pm_photo, on_delete: :nilify_all))
      add(:name, :text, null: false)
      add(:description, :text)
      add(:private_notes, :text)
      add(:revised, :utc_datetime)
      add(:parent_id, references(:pm_category, on_delete: :nilify_all))

      timestamps(type: :utc_datetime_usec)
    end

    create(index(:pm_category, [:cover_photo_id]))
    create(index(:pm_category, [:name, :id]))
    create(index(:pm_category, [:revised]))
    create(index(:pm_category, [:parent_id]))

    create table(:pm_photo_category) do
      add(:photo_id, references(:pm_photo, on_delete: :delete_all), null: false)
      add(:category_id, references(:pm_category, on_delete: :delete_all), null: false)

      timestamps(type: :utc_datetime_usec)
    end

    create(index(:pm_photo_category, [:photo_id, :category_id], unique: true))
    create(index(:pm_photo_category, [:category_id]))

    create table(:pm_category_ascendant) do
      add(:position, :integer, null: false)
      add(:ascendant_id, references(:pm_category, on_delete: :delete_all), null: false)
      add(:descendant_id, references(:pm_category, on_delete: :delete_all), null: false)

      timestamps(type: :utc_datetime_usec)
    end

    create(index(:pm_category_ascendant, [:ascendant_id, :descendant_id], unique: true))
    create(index(:pm_category_ascendant, [:descendant_id]))
  end
end
