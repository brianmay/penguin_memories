defmodule PenguinMemories.StorageTest do
  use ExUnit.Case, async: true

  alias PenguinMemories.Media
  alias PenguinMemories.Photos.File
  alias PenguinMemories.Storage

  describe "get_image_dir" do
    assert Storage.get_image_dir() == "/tmp/images"
  end

  describe "get_image_sizes" do
    Enum.each(
      Storage.get_image_sizes(),
      fn {_, %Media.SizeRequirement{}} -> :ok end
    )
  end

  describe "get_video_sizes" do
    Enum.each(
      Storage.get_video_sizes(),
      fn {_, %Media.SizeRequirement{}} -> :ok end
    )
  end

  describe "build_photo_dir" do
    assert Storage.build_photo_dir(~D[2000-12-30]) == "2000/12/30"
    assert Storage.build_photo_dir(~D[2000-01-03]) == "2000/01/03"
  end

  describe "build_file_dir" do
    assert Storage.build_file_dir("a/b", "mid", false) == "thumb/mid/a/b"
    assert Storage.build_file_dir("a/b", "mid", true) == "video/mid/a/b"
  end

  describe "build_directory" do
    assert Storage.build_directory("a/b") == "/tmp/images/a/b"
  end

  describe "build_filename" do
    assert Storage.build_filename("a/b", "c") == "/tmp/images/a/b/c"
  end

  describe "get_photo_file_path" do
    file = %File{
      dir: "a/b",
      name: "c.jpg"
    }

    assert Storage.get_photo_file_path(file) == "/tmp/images/a/b/c.jpg"
  end
end
