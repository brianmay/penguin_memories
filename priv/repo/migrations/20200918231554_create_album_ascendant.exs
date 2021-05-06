defmodule PenguinMemories.Repo.Migrations.CreateAlbumAscendant do
  use Ecto.Migration

  def change do
    create table(:spud_album_ascendant) do
      add(:position, :integer)
      add(:ascendant_id, references(:spud_album, on_delete: :delete_all))
      add(:descendant_id, references(:spud_album, on_delete: :delete_all))

      timestamps(type: :utc_datetime_usec)
    end

    create(index(:spud_album_ascendant, [:ascendant_id]))
    create(index(:spud_album_ascendant, [:descendant_id]))
  end
end
