defmodule PenguinMemories.Repo.Migrations.CreateAlbumPathTable do
  use Ecto.Migration

  def change do
    create table(:pm_album_path, primary_key: false) do
      add :id, :uuid, primary_key: true, default: fragment("gen_random_uuid()")
      add :descendant_id, references(:pm_album, on_delete: :delete_all), null: false
      add :path_ids, {:array, :integer}, null: false
      add :path_contexts, :map, null: false, default: %{}
      add :path_length, :integer, null: false

      timestamps()
    end

    create index(:pm_album_path, [:descendant_id])
    create index(:pm_album_path, [:path_ids], using: "gin")
    create index(:pm_album_path, [:path_length])

    # Ensure unique paths per descendant (same path_ids array shouldn't be duplicated)
    create unique_index(:pm_album_path, [:descendant_id, :path_ids])
  end
end
