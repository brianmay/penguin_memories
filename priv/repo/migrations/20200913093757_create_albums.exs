defmodule PenguinMemories.Repo.Migrations.CreateAlbums do
  use Ecto.Migration

  def change do
    create table(:pm_album) do
      add(:title, :string, null: false)
      add(:cover_photo_id, :integer)
      add(:description, :text)
      add(:sort_order, :string, null: false)
      add(:sort_name, :string, null: false)
      add(:revised, :utc_datetime)
      add(:revised_utc_offset, :integer)
      add(:parent_id, references(:pm_album, on_delete: :nilify_all))

      timestamps(type: :utc_datetime_usec)
    end

    create(index(:pm_album, [:title]))
    create(index(:pm_album, [:revised]))
    create(index(:pm_album, [:cover_photo_id]))
    create(index(:pm_album, [:parent_id]))

    create table(:pm_photo_album) do
      add(:photo_id, references(:pm_photo, on_delete: :delete_all))
      add(:album_id, references(:pm_album, on_delete: :delete_all))

      timestamps(type: :utc_datetime_usec)
    end

    create(index(:pm_photo_album, [:photo_id]))
    create(index(:pm_photo_album, [:album_id]))
  end
end
