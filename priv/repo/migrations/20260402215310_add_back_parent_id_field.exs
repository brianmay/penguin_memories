defmodule PenguinMemories.Repo.Migrations.AddBackParentIdField do
  use Ecto.Migration

  def change do
    # Add back the parent_id field for backward compatibility
    alter table(:pm_album) do
      add :parent_id, references(:pm_album, on_delete: :nilify_all)
    end

    # Populate parent_id from the first parent in pm_album_parent
    # This chooses one parent for albums that have multiple parents
    execute(
      """
      UPDATE pm_album 
      SET parent_id = ap.parent_id
      FROM pm_album_parent ap
      WHERE pm_album.id = ap.album_id
      AND ap.id = (
        SELECT MIN(id) FROM pm_album_parent 
        WHERE album_id = ap.album_id
      )
      """,
      # Rollback: remove parent_id field
      "ALTER TABLE pm_album DROP COLUMN parent_id"
    )

    create index(:pm_album, :parent_id)
  end
end
