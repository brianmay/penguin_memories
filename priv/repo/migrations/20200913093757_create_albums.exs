defmodule PenguinMemories.Repo.Migrations.CreateAlbums do
  use Ecto.Migration

  def change do
    create table(:pm_album) do
      add(:cover_photo_id, references(:pm_photo, on_delete: :nilify_all))
      add(:name, :text, null: false)
      add(:description, :text)
      add(:private_notes, :text)
      add(:revised, :utc_datetime)
      add(:parent_id, references(:pm_album, on_delete: :nilify_all))

      timestamps(type: :utc_datetime_usec)
    end

    create(index(:pm_album, [:cover_photo_id]))
    create(index(:pm_album, [:name, :id]))
    create(index(:pm_album, [:revised]))
    create(index(:pm_album, [:parent_id]))

    create table(:pm_photo_album) do
      add(:photo_id, references(:pm_photo, on_delete: :delete_all), null: false)
      add(:album_id, references(:pm_album, on_delete: :delete_all), null: false)

      timestamps(type: :utc_datetime_usec)
    end

    create(index(:pm_photo_album, [:photo_id, :album_id], unique: true))
    create(index(:pm_photo_album, [:album_id, :photo_id]))

    create table(:pm_album_ascendant) do
      add(:position, :integer, null: false)
      add(:ascendant_id, references(:pm_album, on_delete: :delete_all), null: false)
      add(:descendant_id, references(:pm_album, on_delete: :delete_all), null: false)

      timestamps(type: :utc_datetime_usec)
    end

    create(index(:pm_album_ascendant, [:ascendant_id, :descendant_id], unique: true))
    create(index(:pm_album_ascendant, [:descendant_id]))
  end
end
