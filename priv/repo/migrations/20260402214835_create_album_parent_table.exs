defmodule PenguinMemories.Repo.Migrations.CreateAlbumParentTable do
  use Ecto.Migration

  def change do
    create table(:pm_album_parent) do
      add :album_id, references(:pm_album, on_delete: :delete_all), null: false
      add :parent_id, references(:pm_album, on_delete: :delete_all), null: false
      add :context_name, :string
      add :context_sort_name, :string
      add :context_cover_photo_id, references(:pm_photo, on_delete: :nilify_all)

      timestamps(type: :utc_datetime_usec)
    end

    create unique_index(:pm_album_parent, [:album_id, :parent_id])
    create index(:pm_album_parent, :album_id)
    create index(:pm_album_parent, :parent_id)
    create index(:pm_album_parent, :context_cover_photo_id)
  end
end
