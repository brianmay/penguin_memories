defmodule PenguinMemories.Uploadtest do
  use ExUnit.Case, async: false
  use PenguinMemories.DataCase

  import File

  alias PenguinMemories.Media
  alias PenguinMemories.Photos.Album
  alias PenguinMemories.Photos.File
  alias PenguinMemories.Photos.Photo
  alias PenguinMemories.Upload

  setup do
    image_dir = Temp.mkdir!()
    Application.put_env(:penguin_memories, :image_dir, image_dir)

    on_exit(fn ->
      rm_rf!(image_dir)
    end)

    {:ok, image_dir: image_dir}
  end

  test "add_exif_to_photo/1" do
    {:ok, media} = Media.get_media("priv/tests/2Y4A3211.JPG")
    photo = %Photo{}

    photo = Upload.add_exif_to_photo(photo, media)
    assert photo.aperture == 4.0
    assert photo.camera_make == "Canon"
    assert photo.camera_model == "Canon EOS R5"
    assert photo.ccd_width == nil
    assert_in_delta(photo.exposure_time, 0.01666666667, 0.0001)
    assert photo.flash_used == false
    assert photo.focal_length == 45
    assert_in_delta(photo.focus_dist, 16.823630030011, 0.0001)
    assert photo.iso_equiv == 2500
    assert photo.metering_mode == "pattern"
  end

  test "get_upload_album/1" do
    root_album =
      %Album{
        title: "Uploads"
      }
      |> Repo.insert!()

    album = Upload.get_upload_album("test")
    %Album{} = album
    assert album.title == "test"
    assert album.parent_id == root_album.id
  end

  test "upload_file/2 simply jpg works", context do
    image_dir = context[:image_dir]

    album =
      %Album{
        title: "test"
      }
      |> Repo.insert!()

    {:ok, photo} = Upload.upload_file("priv/tests/100x100.jpg", album, date: ~D[2000-01-01])
    %Photo{} = photo

    assert length(photo.files) == 1
    file = Enum.at(photo.files, 0)
    %File{} = file
    assert file.dir == "orig/2000/01/01"
    assert file.name == "100x100.jpg"
    assert file.size_key == "orig"
    assert file.is_video == false
    assert file.width == 100
    assert file.height == 100

    assert photo.action == "R"
    assert length(photo.albums) == 1
    %Album{} = Enum.at(photo.albums, 0)
    assert Enum.at(photo.albums, 0).id == album.id
    assert photo.aperture == nil
    assert photo.camera_make == nil
    assert photo.camera_model == nil
    assert photo.ccd_width == nil
    assert photo.comment == nil
    %DateTime{} = photo.datetime
    assert is_integer(photo.utc_offset)
    assert photo.description == nil
    assert photo.exposure_time == nil
    assert photo.flash_used == nil
    assert photo.focal_length == nil
    assert photo.focus_dist == nil
    %DateTime{} = photo.inserted_at
    assert photo.iso_equiv == nil
    assert photo.metering_mode == nil
    assert photo.name == "100x100.jpg"
    assert photo.dir == "2000/01/01"
    assert photo.photographer_id == nil
    assert photo.place_id == nil
    assert photo.rating == nil
    assert photo.title == nil
    %DateTime{} = photo.updated_at
    assert photo.view == nil

    {:ok, media} = Media.get_media("#{image_dir}/orig/2000/01/01/100x100.jpg")
    %Media{} = media
    assert Media.get_size(media) == %Media.Size{width: 100, height: 100}
  end

  test "upload_file/2 exif jpg works", context do
    image_dir = context[:image_dir]

    album =
      %Album{
        title: "test"
      }
      |> Repo.insert!()

    {:ok, photo} = Upload.upload_file("priv/tests/2Y4A3211.JPG", album, date: ~D[2000-01-01])
    %Photo{} = photo

    assert length(photo.files) == 1
    file = Enum.at(photo.files, 0)
    %File{} = file
    assert file.dir == "orig/2000/01/01"
    assert file.name == "2Y4A3211.jpg"
    assert file.size_key == "orig"
    assert file.is_video == false
    assert file.width == 8192
    assert file.height == 5464

    assert photo.action == "R"
    assert length(photo.albums) == 1
    %Album{} = Enum.at(photo.albums, 0)
    assert Enum.at(photo.albums, 0).id == album.id
    assert photo.aperture == 4.0
    assert photo.camera_make == "Canon"
    assert photo.camera_model == "Canon EOS R5"
    assert photo.ccd_width == nil
    assert photo.comment == nil
    assert photo.datetime == ~U[2021-04-01 03:32:00Z]
    assert photo.utc_offset == 600
    assert photo.description == nil
    assert_in_delta(photo.exposure_time, 0.01666666667, 0.0001)
    assert photo.flash_used == false
    assert photo.focal_length == 45
    assert_in_delta(photo.focus_dist, 16.823630030011, 0.0001)
    %DateTime{} = photo.inserted_at
    assert photo.iso_equiv == 2500
    assert photo.metering_mode == "pattern"
    assert photo.name == "2Y4A3211.JPG"
    assert photo.dir == "2000/01/01"
    assert photo.photographer_id == nil
    assert photo.place_id == nil
    assert photo.rating == nil
    assert photo.title == nil
    %DateTime{} = photo.updated_at
    assert photo.view == nil

    {:ok, media} = Media.get_media("#{image_dir}/orig/2000/01/01/2Y4A3211.jpg")
    %Media{} = media
    assert Media.get_size(media) == %Media.Size{width: 8192, height: 5464}
  end

  test "upload_file/2 exif cr2 works", context do
    image_dir = context[:image_dir]

    album =
      %Album{
        title: "test"
      }
      |> Repo.insert!()

    {:ok, photo} = Upload.upload_file("priv/tests/IMG_4706.CR2", album, date: ~D[2000-01-01])
    %Photo{} = photo

    assert length(photo.files) == 1
    file = Enum.at(photo.files, 0)
    %File{} = file
    assert file.dir == "orig/2000/01/01"
    assert file.name == "IMG_4706.cr2"
    assert file.size_key == "orig"
    assert file.is_video == false
    assert file.width == 3474
    assert file.height == 2314

    assert photo.action == "R"
    assert length(photo.albums) == 1
    %Album{} = Enum.at(photo.albums, 0)
    assert Enum.at(photo.albums, 0).id == album.id
    assert photo.aperture == 16.0
    assert photo.camera_make == "Canon"
    assert photo.camera_model == "Canon EOS 350D DIGITAL"
    assert photo.ccd_width == nil
    assert photo.comment == nil
    assert photo.datetime == ~U[2005-03-18 23:57:13Z]
    assert photo.utc_offset == 600
    assert photo.description == nil
    assert_in_delta(photo.exposure_time, 0.01, 0.0001)
    assert photo.flash_used == false
    assert photo.focal_length == 155
    assert_in_delta(photo.focus_dist, 81.0705641337023, 0.0001)
    %DateTime{} = photo.inserted_at
    assert photo.iso_equiv == 100
    assert photo.metering_mode == "pattern"
    assert photo.name == "IMG_4706.CR2"
    assert photo.dir == "2000/01/01"
    assert photo.photographer_id == nil
    assert photo.place_id == nil
    assert photo.rating == nil
    assert photo.title == nil
    %DateTime{} = photo.updated_at
    assert photo.view == nil

    {:ok, media} = Media.get_media("#{image_dir}/orig/2000/01/01/IMG_4706.cr2")
    %Media{} = media
    assert Media.get_size(media) == %Media.Size{width: 3474, height: 2314}
  end

  test "upload_file/2 exif mp4 works", context do
    image_dir = context[:image_dir]

    album =
      %Album{
        title: "test"
      }
      |> Repo.insert!()

    {:ok, photo} = Upload.upload_file("priv/tests/MVI_7254.mp4", album, date: ~D[2000-01-01])
    %Photo{} = photo

    assert length(photo.files) == 1
    file = Enum.at(photo.files, 0)
    %File{} = file
    assert file.dir == "orig/2000/01/01"
    assert file.name == "MVI_7254.mp4"
    assert file.size_key == "orig"
    assert file.is_video == true
    assert file.width == 480
    assert file.height == 270

    assert photo.action == "R"
    assert length(photo.albums) == 1
    %Album{} = Enum.at(photo.albums, 0)
    assert Enum.at(photo.albums, 0).id == album.id
    assert photo.aperture == nil
    assert photo.camera_make == nil
    assert photo.camera_model == nil
    assert photo.ccd_width == nil
    assert photo.comment == nil
    %DateTime{} = photo.datetime
    assert is_integer(photo.utc_offset)
    assert photo.description == nil
    assert photo.exposure_time == nil
    assert photo.flash_used == nil
    assert photo.focal_length == nil
    assert photo.focus_dist == nil
    %DateTime{} = photo.inserted_at
    assert photo.iso_equiv == nil
    assert photo.metering_mode == nil
    assert photo.name == "MVI_7254.mp4"
    assert photo.dir == "2000/01/01"
    assert photo.photographer_id == nil
    assert photo.place_id == nil
    assert photo.rating == nil
    assert photo.title == nil
    %DateTime{} = photo.updated_at
    assert photo.view == nil

    {:ok, media} = Media.get_media("#{image_dir}/orig/2000/01/01/MVI_7254.mp4")
    %Media{} = media
    assert Media.get_size(media) == %Media.Size{width: 480, height: 270}
  end

  test "upload_file/2 exif ogv works", context do
    image_dir = context[:image_dir]

    album =
      %Album{
        title: "test"
      }
      |> Repo.insert!()

    {:ok, photo} = Upload.upload_file("priv/tests/MVI_7254.ogv", album, date: ~D[2000-01-01])
    %Photo{} = photo

    assert length(photo.files) == 1
    file = Enum.at(photo.files, 0)
    %File{} = file
    assert file.dir == "orig/2000/01/01"
    assert file.name == "MVI_7254.ogv"
    assert file.size_key == "orig"
    assert file.is_video == true
    assert file.width == 480
    assert file.height == 270

    assert photo.action == "R"
    assert length(photo.albums) == 1
    %Album{} = Enum.at(photo.albums, 0)
    assert Enum.at(photo.albums, 0).id == album.id
    assert photo.aperture == nil
    assert photo.camera_make == nil
    assert photo.camera_model == nil
    assert photo.ccd_width == nil
    assert photo.comment == nil
    %DateTime{} = photo.datetime
    assert is_integer(photo.utc_offset)
    assert photo.description == nil
    assert photo.exposure_time == nil
    assert photo.flash_used == nil
    assert photo.focal_length == nil
    assert photo.focus_dist == nil
    %DateTime{} = photo.inserted_at
    assert photo.iso_equiv == nil
    assert photo.metering_mode == nil
    assert photo.name == "MVI_7254.ogv"
    assert photo.dir == "2000/01/01"
    assert photo.photographer_id == nil
    assert photo.place_id == nil
    assert photo.rating == nil
    assert photo.title == nil
    %DateTime{} = photo.updated_at
    assert photo.view == nil

    {:ok, media} = Media.get_media("#{image_dir}/orig/2000/01/01/MVI_7254.ogv")
    %Media{} = media
    assert Media.get_size(media) == %Media.Size{width: 480, height: 270}
  end

  test "upload_file/2 exif webm works", context do
    image_dir = context[:image_dir]

    album =
      %Album{
        title: "test"
      }
      |> Repo.insert!()

    {:ok, photo} = Upload.upload_file("priv/tests/MVI_7254.webm", album, date: ~D[2000-01-01])
    %Photo{} = photo

    assert length(photo.files) == 1
    file = Enum.at(photo.files, 0)
    %File{} = file
    assert file.dir == "orig/2000/01/01"
    assert file.name == "MVI_7254.webm"
    assert file.size_key == "orig"
    assert file.is_video == true
    assert file.width == 480
    assert file.height == 270

    assert photo.action == "R"
    assert length(photo.albums) == 1
    %Album{} = Enum.at(photo.albums, 0)
    assert Enum.at(photo.albums, 0).id == album.id
    assert photo.aperture == nil
    assert photo.camera_make == nil
    assert photo.camera_model == nil
    assert photo.ccd_width == nil
    assert photo.comment == nil
    %DateTime{} = photo.datetime
    assert is_integer(photo.utc_offset)
    assert photo.description == nil
    assert photo.exposure_time == nil
    assert photo.flash_used == nil
    assert photo.focal_length == nil
    assert photo.focus_dist == nil
    %DateTime{} = photo.inserted_at
    assert photo.iso_equiv == nil
    assert photo.metering_mode == nil
    assert photo.name == "MVI_7254.webm"
    assert photo.dir == "2000/01/01"
    assert photo.photographer_id == nil
    assert photo.place_id == nil
    assert photo.rating == nil
    assert photo.title == nil
    %DateTime{} = photo.updated_at
    assert photo.view == nil

    {:ok, media} = Media.get_media("#{image_dir}/orig/2000/01/01/MVI_7254.webm")
    %Media{} = media
    assert Media.get_size(media) == %Media.Size{width: 480, height: 270}
  end

  test "upload_directory/2 exif works" do
    %Album{
      title: "Uploads"
    }
    |> Repo.insert!()

    Upload.upload_directory("priv/tests")
  end
end
