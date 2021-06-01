defmodule PenguinMemories.Database.Conflicts do
  @moduledoc """
  Detect conflicts with new files.
  """
  import Ecto.Query

  alias PenguinMemories.Media
  alias PenguinMemories.Photos.File
  alias PenguinMemories.Photos.Photo
  alias PenguinMemories.Repo

  @spec get_file_dir_conflicts(String.t(), String.t()) :: list(Photo.t())
  def get_file_dir_conflicts(new_dir, new_name) do
    file_query =
      from f in File,
        where: f.dir == ^new_dir and f.filename == ^new_name

    Repo.all(file_query)
  end

  @spec get_file_hash_conflict(Media.t(), String.t()) :: Photo.t() | nil
  def get_file_hash_conflict(%Media{} = media, size_key) do
    num_bytes = Media.get_num_bytes(media)
    sha256_hash = Media.get_sha256_hash(media)

    query =
      from p in Photo,
        join: f in File,
        on: p.id == f.photo_id,
        where:
          f.size_key == ^size_key and f.num_bytes == ^num_bytes and
            f.sha256_hash == ^sha256_hash,
        preload: [:albums, :files, :photo_relations]

    Repo.one(query)
  end
end
