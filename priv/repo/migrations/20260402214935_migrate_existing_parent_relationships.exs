defmodule PenguinMemories.Repo.Migrations.MigrateExistingParentRelationships do
  use Ecto.Migration

  def change do
    # First, migrate existing parent_id relationships to the new table
    execute(
      """
      INSERT INTO pm_album_parent (album_id, parent_id, inserted_at, updated_at)
      SELECT id, parent_id, NOW(), NOW()
      FROM pm_album
      WHERE parent_id IS NOT NULL
      """,
      # Rollback: restore parent_id relationships
      """
      UPDATE pm_album 
      SET parent_id = ap.parent_id
      FROM pm_album_parent ap
      WHERE pm_album.id = ap.album_id
      """
    )

    # Then remove the old parent_id column
    alter table(:pm_album) do
      remove :parent_id
    end
  end
end
