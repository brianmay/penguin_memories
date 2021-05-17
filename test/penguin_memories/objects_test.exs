defmodule PenguinMemories.ObjectsTest do
  use ExUnit.Case, async: true
  use PenguinMemories.DataCase

  alias PenguinMemories.Media
  alias PenguinMemories.Objects
  alias PenguinMemories.Photos.File
  alias PenguinMemories.Photos.Photo

  describe "check conflicts" do
    test "get_file_dir_conflicts/2" do
      {:ok, media1} = Media.get_media("priv/tests/100x100.jpg")

      photo =
        %Photo{
          dir: "d/e/f",
          name: "goodbye.jpg",
          datetime: ~U[2000-01-01 12:00:00Z],
          utc_offset: 0
        }
        |> Repo.insert!()

      file =
        %File{
          dir: "a/b/c",
          name: "hello.jpg",
          size_key: "orig",
          num_bytes: Media.get_num_bytes(media1),
          sha256_hash: Media.get_sha256_hash(media1),
          width: 10,
          height: 10,
          mime_type: "penguin/cute",
          photo_id: photo.id
        }
        |> Repo.insert!()

      conflicts = Objects.get_file_dir_conflicts("a/b/c", "hello.jpg")
      assert length(conflicts) == 1
      assert Enum.at(conflicts, 0).id == file.id

      conflicts = Objects.get_file_dir_conflicts("a/b/c", "HELLO.JPG")
      assert conflicts == []

      conflicts = Objects.get_file_dir_conflicts("a/b/c", "hello.png")
      assert conflicts == []

      conflicts = Objects.get_file_dir_conflicts("a/b/d", "hello.png")
      assert conflicts == []

      conflicts = Objects.get_file_dir_conflicts("a/b/c", "goodbye.png")
      assert conflicts == []
    end

    test "get_file_hash_conflict/2" do
      {:ok, media1} = Media.get_media("priv/tests/100x100.jpg")
      {:ok, media2} = Media.get_media("priv/tests/100x100.png")

      photo =
        %Photo{
          dir: "a/b/c",
          name: "hello.jpg",
          datetime: ~U[2000-01-01 12:00:00Z],
          utc_offset: 0
        }
        |> Repo.insert!()

      %File{
        dir: "a/b/c",
        name: "hello.jpg",
        size_key: "orig",
        num_bytes: Media.get_num_bytes(media1),
        sha256_hash: Media.get_sha256_hash(media1),
        width: 10,
        height: 10,
        mime_type: "penguin/cute",
        photo_id: photo.id
      }
      |> Repo.insert!()

      conflict = Objects.get_file_hash_conflict(media1, "orig")
      %Photo{} = conflict
      assert conflict.id == photo.id

      conflict = Objects.get_file_hash_conflict(media2, "orig")
      assert conflict == nil
    end
  end
end
