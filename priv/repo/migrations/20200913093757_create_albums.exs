defmodule PenguinMemories.Repo.Migrations.CreateAlbums do
  use Ecto.Migration

  def change do
    create table(:spud_album) do
      add(:title, :string, null: false)
      add(:cover_photo_id, :integer)
      add(:description, :text)
      add(:sort_order, :string, null: false)
      add(:sort_name, :string, null: false)
      add(:revised, :utc_datetime)
      add(:revised_utc_offset, :integer)
      add(:parent_id, references(:spud_album, on_delete: :nilify_all))

      timestamps(type: :utc_datetime_usec)
    end

    create(index(:spud_album, [:title]))
    create(index(:spud_album, [:revised]))
    create(index(:spud_album, [:cover_photo_id]))
    create(index(:spud_album, [:parent_id]))

    create table(:spud_photo_album) do
      add(:photo_id, references(:spud_photo, on_delete: :delete_all))
      add(:album_id, references(:spud_album, on_delete: :delete_all))

      timestamps(type: :utc_datetime_usec)
    end

    create(index(:spud_photo_album, [:photo_id]))
    create(index(:spud_photo_album, [:album_id]))
  end
end
