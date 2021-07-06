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

    PenguinMemories.Database.Impl.Index.Mock
    |> Mox.stub(:get_parent_ids, fn _, _ -> [] end)
    |> Mox.stub(:get_child_ids, fn _, _ -> [] end)
    |> Mox.stub(:get_index, fn _, _ -> MapSet.new() end)
    |> Mox.stub(:create_index, fn _, _, _ -> :ok end)
    |> Mox.stub(:set_done, fn _, _ -> :ok end)

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
        name: "Uploads",
        sort_name: "Uploads"
      }
      |> Repo.insert!()

    album = Upload.get_upload_album("test")
    %Album{} = album
    assert album.name == "test"
    assert album.parent_id == root_album.id
  end

  @tag :slow
  test "upload_file/2 simply jpg works", context do
    image_dir = context[:image_dir]

    album =
      %Album{
        name: "test"
      }
      |> Repo.insert!()

    {:ok, photo} = Upload.upload_file("priv/tests/100x100.jpg", album, date: ~D[2000-01-01])
    %Photo{} = photo

    filename =
      photo.id
      |> Integer.to_string()
      |> String.pad_leading(8, "0")

    assert length(photo.files) == 1
    file = Enum.at(photo.files, 0)
    %File{} = file
    assert file.dir == "orig/2000/01/01"
    assert file.filename == "#{filename}.jpg"
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
    assert photo.private_notes == nil
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
    assert photo.filename == "100x100.jpg"
    assert photo.dir == "2000/01/01"
    assert photo.photographer_id == nil
    assert photo.place_id == nil
    assert photo.rating == nil
    assert photo.name == nil
    %DateTime{} = photo.updated_at
    assert photo.view == nil

    {:ok, media} = Media.get_media("#{image_dir}/orig/2000/01/01/#{filename}.jpg")
    %Media{} = media
    assert Media.get_size(media) == %Media.Size{width: 100, height: 100}
  end

  @tag :slow
  test "upload_file/2 exif jpg works", context do
    image_dir = context[:image_dir]

    album =
      %Album{
        name: "test"
      }
      |> Repo.insert!()

    {:ok, photo} = Upload.upload_file("priv/tests/2Y4A3211.JPG", album, date: ~D[2000-01-01])
    %Photo{} = photo

    filename =
      photo.id
      |> Integer.to_string()
      |> String.pad_leading(8, "0")

    assert length(photo.files) == 1
    file = Enum.at(photo.files, 0)
    %File{} = file
    assert file.dir == "orig/2000/01/01"
    assert file.filename == "#{filename}.jpg"
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
    assert photo.private_notes == nil
    assert photo.datetime == ~U[2021-04-01 03:32:00Z]
    assert photo.utc_offset == 660
    assert photo.description == nil
    assert_in_delta(photo.exposure_time, 0.01666666667, 0.0001)
    assert photo.flash_used == false
    assert photo.focal_length == 45
    assert_in_delta(photo.focus_dist, 16.823630030011, 0.0001)
    %DateTime{} = photo.inserted_at
    assert photo.iso_equiv == 2500
    assert photo.metering_mode == "pattern"
    assert photo.filename == "2Y4A3211.JPG"
    assert photo.dir == "2000/01/01"
    assert photo.photographer_id == nil
    assert photo.place_id == nil
    assert photo.rating == nil
    assert photo.name == nil
    %DateTime{} = photo.updated_at
    assert photo.view == nil

    {:ok, media} = Media.get_media("#{image_dir}/orig/2000/01/01/#{filename}.jpg")
    %Media{} = media
    assert Media.get_size(media) == %Media.Size{width: 8192, height: 5464}
  end

  @tag :slow
  test "upload_file/2 exif cr2 works", context do
    image_dir = context[:image_dir]

    album =
      %Album{
        name: "test"
      }
      |> Repo.insert!()

    {:ok, photo} = Upload.upload_file("priv/tests/IMG_4706.CR2", album, date: ~D[2000-01-01])
    %Photo{} = photo

    filename =
      photo.id
      |> Integer.to_string()
      |> String.pad_leading(8, "0")

    assert length(photo.files) == 1
    file = Enum.at(photo.files, 0)
    %File{} = file
    assert file.dir == "orig/2000/01/01"
    assert file.filename == "#{filename}.cr2"
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
    assert photo.private_notes == nil
    assert photo.datetime == ~U[2005-03-18 23:57:13Z]
    assert photo.utc_offset == 660
    assert photo.description == nil
    assert_in_delta(photo.exposure_time, 0.01, 0.0001)
    assert photo.flash_used == false
    assert photo.focal_length == 155
    assert_in_delta(photo.focus_dist, 81.0705641337023, 0.0001)
    %DateTime{} = photo.inserted_at
    assert photo.iso_equiv == 100
    assert photo.metering_mode == "pattern"
    assert photo.filename == "IMG_4706.CR2"
    assert photo.dir == "2000/01/01"
    assert photo.photographer_id == nil
    assert photo.place_id == nil
    assert photo.rating == nil
    assert photo.name == nil
    %DateTime{} = photo.updated_at
    assert photo.view == nil

    {:ok, media} = Media.get_media("#{image_dir}/orig/2000/01/01/#{filename}.cr2")
    %Media{} = media
    assert Media.get_size(media) == %Media.Size{width: 3474, height: 2314}
  end

  @tag :slow
  test "upload_file/2 exif mp4 works", context do
    image_dir = context[:image_dir]

    album =
      %Album{
        name: "test"
      }
      |> Repo.insert!()

    {:ok, photo} = Upload.upload_file("priv/tests/MVI_7254.mp4", album, date: ~D[2000-01-01])
    %Photo{} = photo

    filename =
      photo.id
      |> Integer.to_string()
      |> String.pad_leading(8, "0")

    assert length(photo.files) == 1
    file = Enum.at(photo.files, 0)
    %File{} = file
    assert file.dir == "orig/2000/01/01"
    assert file.filename == "#{filename}.mp4"
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
    assert photo.private_notes == nil
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
    assert photo.filename == "MVI_7254.mp4"
    assert photo.dir == "2000/01/01"
    assert photo.photographer_id == nil
    assert photo.place_id == nil
    assert photo.rating == nil
    assert photo.name == nil
    %DateTime{} = photo.updated_at
    assert photo.view == nil

    {:ok, media} = Media.get_media("#{image_dir}/orig/2000/01/01/#{filename}.mp4")
    %Media{} = media
    assert Media.get_size(media) == %Media.Size{width: 480, height: 270}
  end

  @tag :slow
  test "upload_file/2 exif ogv works", context do
    image_dir = context[:image_dir]

    album =
      %Album{
        name: "test"
      }
      |> Repo.insert!()

    {:ok, photo} = Upload.upload_file("priv/tests/MVI_7254.ogv", album, date: ~D[2000-01-01])
    %Photo{} = photo

    filename =
      photo.id
      |> Integer.to_string()
      |> String.pad_leading(8, "0")

    assert length(photo.files) == 1
    file = Enum.at(photo.files, 0)
    %File{} = file
    assert file.dir == "orig/2000/01/01"
    assert file.filename == "#{filename}.ogv"
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
    assert photo.private_notes == nil
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
    assert photo.filename == "MVI_7254.ogv"
    assert photo.dir == "2000/01/01"
    assert photo.photographer_id == nil
    assert photo.place_id == nil
    assert photo.rating == nil
    assert photo.name == nil
    %DateTime{} = photo.updated_at
    assert photo.view == nil

    {:ok, media} = Media.get_media("#{image_dir}/orig/2000/01/01/#{filename}.ogv")
    %Media{} = media
    assert Media.get_size(media) == %Media.Size{width: 480, height: 270}
  end

  @tag :slow
  test "upload_file/2 exif webm works", context do
    image_dir = context[:image_dir]

    album =
      %Album{
        name: "test"
      }
      |> Repo.insert!()

    {:ok, photo} = Upload.upload_file("priv/tests/MVI_7254.webm", album, date: ~D[2000-01-01])
    %Photo{} = photo

    filename =
      photo.id
      |> Integer.to_string()
      |> String.pad_leading(8, "0")

    assert length(photo.files) == 1
    file = Enum.at(photo.files, 0)
    %File{} = file
    assert file.dir == "orig/2000/01/01"
    assert file.filename == "#{filename}.webm"
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
    assert photo.private_notes == nil
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
    assert photo.filename == "MVI_7254.webm"
    assert photo.dir == "2000/01/01"
    assert photo.photographer_id == nil
    assert photo.place_id == nil
    assert photo.rating == nil
    assert photo.name == nil
    %DateTime{} = photo.updated_at
    assert photo.view == nil

    {:ok, media} = Media.get_media("#{image_dir}/orig/2000/01/01/#{filename}.webm")
    %Media{} = media
    assert Media.get_size(media) == %Media.Size{width: 480, height: 270}
  end

  @tag :slow
  test "upload_directory/2 exif works" do
    %Album{
      name: "Uploads"
    }
    |> Repo.insert!()

    Upload.upload_directory("priv/tests")
  end
end
