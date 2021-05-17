defmodule PenguinMemories.StorageTest do
  use ExUnit.Case, async: false

  import File

  alias PenguinMemories.Media
  alias PenguinMemories.Photos.File
  alias PenguinMemories.Photos.Photo
  alias PenguinMemories.Storage

  setup_all do
    :ok
  end

  setup do
    image_dir = Temp.mkdir!()
    Application.put_env(:penguin_memories, :image_dir, image_dir)

    on_exit(fn ->
      rm_rf!(image_dir)
    end)

    {:ok, image_dir: image_dir}
  end

  test "get_image_dir works", context do
    assert Storage.get_image_dir() == context[:image_dir]
  end

  test "get_sizes works" do
    Enum.each(
      Storage.get_sizes(),
      fn {_, sizes} ->
        Enum.each(sizes, fn %Media.SizeRequirement{} -> :ok end)
      end
    )
  end

  test "build_photo_dir works" do
    assert Storage.build_photo_dir(~D[2000-12-30]) == "2000/12/30"
    assert Storage.build_photo_dir(~D[2000-01-03]) == "2000/01/03"
  end

  test "build_file_dir works" do
    assert Storage.build_file_dir("a/b", "mid", false) == "thumb/mid/a/b"
    assert Storage.build_file_dir("a/b", "mid", true) == "video/mid/a/b"
  end

  test "build_directory works", context do
    image_dir = context[:image_dir]
    assert Storage.build_directory("a/b") == "#{image_dir}/a/b"
  end

  test "build_path works", context do
    image_dir = context[:image_dir]
    assert Storage.build_path("a/b", "c") == "#{image_dir}/a/b/c"
  end

  test "get_photo_file_path works", context do
    image_dir = context[:image_dir]

    file = %File{
      dir: "a/b",
      name: "c.jpg"
    }

    assert Storage.get_photo_file_path(file) == "#{image_dir}/a/b/c.jpg"
  end

  test "get_photo_file_media works", context do
    image_dir = context[:image_dir]

    file = %File{
      dir: "a/b",
      name: "c.jpg",
      mime_type: "image/penguin"
    }

    mkdir_p!("#{image_dir}/a/b")
    copy!("priv/tests/100x100.jpg", "#{image_dir}/a/b/c.jpg")

    {:ok, media} = Storage.get_photo_file_media(file)
    %Media{} = media
    assert media.path == "#{image_dir}/a/b/c.jpg"
    assert media.type == "image"
    assert media.subtype == "penguin"
  end

  test "build_file_from_media works", context do
    image_dir = context[:image_dir]

    photo = %Photo{
      id: 1,
      name: "test.wot",
      dir: "1/2/3"
    }

    {:ok, media} = Media.get_media("priv/tests/100x100.jpg")
    sha256_hash = Media.get_sha256_hash(media)

    {:ok, file} = Storage.build_file_from_media(photo, media, "thumb")

    assert %File{
             photo_id: 1,
             name: "00000001.jpg",
             dir: "thumb/thumb/1/2/3",
             height: 100,
             width: 100,
             mime_type: "image/jpeg",
             num_bytes: 2917,
             size_key: "thumb",
             sha256_hash: sha256_hash
           } == file

    {:ok, new_media} = Media.get_media("#{image_dir}/thumb/thumb/1/2/3/00000001.jpg")
    assert Media.get_size(new_media) == %Media.Size{width: 100, height: 100}
    assert Media.get_num_bytes(new_media) == 2917
    assert Media.get_sha256_hash(new_media) == sha256_hash
  end
end
