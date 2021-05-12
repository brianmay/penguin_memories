defmodule PenguinMemories.Actionstest do
  use ExUnit.Case, async: false
  use PenguinMemories.DataCase

  import File

  alias PenguinMemories.Actions
  alias PenguinMemories.Media
  alias PenguinMemories.Photos.Album
  alias PenguinMemories.Photos.File
  alias PenguinMemories.Photos.Photo
  alias PenguinMemories.Storage
  alias PenguinMemories.Upload

  setup do
    image_dir = Temp.mkdir!()
    Application.put_env(:penguin_memories, :image_dir, image_dir)

    on_exit(fn ->
      rm_rf!(image_dir)
    end)

    {:ok, image_dir: image_dir}
  end

  test "upload_file/2 works jpg", context do
    image_dir = context[:image_dir]

    album =
      %Album{
        title: "test"
      }
      |> Repo.insert!()

    {:ok, photo} = Upload.upload_file("priv/tests/2Y4A3211.JPG", album, date: ~D[2000-01-01])

    new_photo = Actions.process_photo(photo)
    %Photo{} = new_photo

    files = Enum.sort_by(new_photo.files, fn v -> {v.mime_type, v.width, -v.id} end)
    assert length(files) == 7

    [file | files] = files
    assert file.size_key == "thumb"
    assert file.width == 120
    assert file.height == 80
    assert file.is_video == false
    assert file.mime_type == "image/gif"
    assert file.dir == "thumb/thumb/2000/01/01"
    assert file.name == "2Y4A3211.gif"

    [file | files] = files
    assert file.size_key == "mid"
    assert file.width == 480
    assert file.height == 320
    assert file.is_video == false
    assert file.mime_type == "image/gif"
    assert file.dir == "thumb/mid/2000/01/01"
    assert file.name == "2Y4A3211.gif"

    [file | files] = files
    assert file.size_key == "large"
    assert file.width == 1919
    assert file.height == 1280
    assert file.is_video == false
    assert file.mime_type == "image/gif"
    assert file.dir == "thumb/large/2000/01/01"
    assert file.name == "2Y4A3211.gif"

    [file | files] = files
    assert file.size_key == "thumb"
    assert file.width == 120
    assert file.height == 80
    assert file.is_video == false
    assert file.mime_type == "image/jpeg"
    assert file.dir == "thumb/thumb/2000/01/01"
    assert file.name == "2Y4A3211.jpg"

    [file | files] = files
    assert file.size_key == "mid"
    assert file.width == 480
    assert file.height == 320
    assert file.is_video == false
    assert file.mime_type == "image/jpeg"
    assert file.dir == "thumb/mid/2000/01/01"
    assert file.name == "2Y4A3211.jpg"

    [file | files] = files
    assert file.size_key == "large"
    assert file.width == 1919
    assert file.height == 1280
    assert file.is_video == false
    assert file.mime_type == "image/jpeg"
    assert file.dir == "thumb/large/2000/01/01"
    assert file.name == "2Y4A3211.jpg"

    [file | files] = files
    assert file.size_key == "orig"
    assert file.width == 8192
    assert file.height == 5464
    assert file.is_video == false
    assert file.mime_type == "image/jpeg"
    assert file.dir == "orig/2000/01/01"
    assert file.name == "2Y4A3211.jpg"

    [] = files

    {:ok, _media} = Media.get_media("#{image_dir}/orig/2000/01/01/2Y4A3211.jpg")
    {:ok, _media} = Media.get_media("#{image_dir}/thumb/thumb/2000/01/01/2Y4A3211.jpg")
    {:ok, _media} = Media.get_media("#{image_dir}/thumb/mid/2000/01/01/2Y4A3211.jpg")
    {:ok, _media} = Media.get_media("#{image_dir}/thumb/large/2000/01/01/2Y4A3211.jpg")
    {:ok, _media} = Media.get_media("#{image_dir}/thumb/thumb/2000/01/01/2Y4A3211.gif")
    {:ok, _media} = Media.get_media("#{image_dir}/thumb/mid/2000/01/01/2Y4A3211.gif")
    {:ok, _media} = Media.get_media("#{image_dir}/thumb/large/2000/01/01/2Y4A3211.gif")
  end

  test "upload_file/2 works webm", context do
    image_dir = context[:image_dir]

    album =
      %Album{
        title: "test"
      }
      |> Repo.insert!()

    {:ok, photo} = Upload.upload_file("priv/tests/MVI_7254.webm", album, date: ~D[2000-01-01])

    new_photo = Actions.process_photo(photo)
    %Photo{} = new_photo

    files = Enum.sort_by(new_photo.files, fn v -> {v.mime_type, v.width, -v.id} end)
    assert length(files) == 16

    [file | files] = files
    assert file.size_key == "thumb"
    assert file.width == 120
    assert file.height == 68
    assert file.is_video == false
    assert file.mime_type == "image/gif"
    assert file.dir == "thumb/thumb/2000/01/01"
    assert file.name == "MVI_7254.gif"

    [file | files] = files
    assert file.size_key == "mid"
    assert file.width == 480
    assert file.height == 270
    assert file.is_video == false
    assert file.mime_type == "image/gif"
    assert file.dir == "thumb/mid/2000/01/01"
    assert file.name == "MVI_7254.gif"

    [file | files] = files
    assert file.size_key == "large"
    assert file.width == 480
    assert file.height == 270
    assert file.is_video == false
    assert file.mime_type == "image/gif"
    assert file.dir == "thumb/large/2000/01/01"
    assert file.name == "MVI_7254.gif"

    [file | files] = files
    assert file.size_key == "thumb"
    assert file.width == 120
    assert file.height == 68
    assert file.is_video == false
    assert file.mime_type == "image/jpeg"
    assert file.dir == "thumb/thumb/2000/01/01"
    assert file.name == "MVI_7254.jpg"

    [file | files] = files
    assert file.size_key == "mid"
    assert file.width == 480
    assert file.height == 270
    assert file.is_video == false
    assert file.mime_type == "image/jpeg"
    assert file.dir == "thumb/mid/2000/01/01"
    assert file.name == "MVI_7254.jpg"

    [file | files] = files
    assert file.size_key == "large"
    assert file.width == 480
    assert file.height == 270
    assert file.is_video == false
    assert file.mime_type == "image/jpeg"
    assert file.dir == "thumb/large/2000/01/01"
    assert file.name == "MVI_7254.jpg"

    [file | files] = files
    assert file.size_key == "thumb"
    assert file.width == 120
    assert file.height == 68
    assert file.is_video == true
    assert file.mime_type == "video/mp4"
    assert file.dir == "video/thumb/2000/01/01"
    assert file.name == "MVI_7254.mp4"

    [file | files] = files
    assert file.size_key == "mid"
    assert file.width == 480
    assert file.height == 270
    assert file.is_video == true
    assert file.mime_type == "video/mp4"
    assert file.dir == "video/mid/2000/01/01"
    assert file.name == "MVI_7254.mp4"

    [file | files] = files
    assert file.size_key == "large"
    assert file.width == 480
    assert file.height == 270
    assert file.is_video == true
    assert file.mime_type == "video/mp4"
    assert file.dir == "video/large/2000/01/01"
    assert file.name == "MVI_7254.mp4"

    [file | files] = files
    assert file.size_key == "thumb"
    assert file.width == 120
    assert file.height == 68
    assert file.is_video == true
    assert file.mime_type == "video/ogg"
    assert file.dir == "video/thumb/2000/01/01"
    assert file.name == "MVI_7254.ogv"

    [file | files] = files
    assert file.size_key == "mid"
    assert file.width == 480
    assert file.height == 270
    assert file.is_video == true
    assert file.mime_type == "video/ogg"
    assert file.dir == "video/mid/2000/01/01"
    assert file.name == "MVI_7254.ogv"

    [file | files] = files
    assert file.size_key == "large"
    assert file.width == 480
    assert file.height == 270
    assert file.is_video == true
    assert file.mime_type == "video/ogg"
    assert file.dir == "video/large/2000/01/01"
    assert file.name == "MVI_7254.ogv"

    [file | files] = files
    assert file.size_key == "thumb"
    assert file.width == 120
    assert file.height == 68
    assert file.is_video == true
    assert file.mime_type == "video/webm"
    assert file.dir == "video/thumb/2000/01/01"
    assert file.name == "MVI_7254.webm"

    [file | files] = files
    assert file.size_key == "mid"
    assert file.width == 480
    assert file.height == 270
    assert file.is_video == true
    assert file.mime_type == "video/webm"
    assert file.dir == "video/mid/2000/01/01"
    assert file.name == "MVI_7254.webm"

    [file | files] = files
    assert file.size_key == "large"
    assert file.width == 480
    assert file.height == 270
    assert file.is_video == true
    assert file.mime_type == "video/webm"
    assert file.dir == "video/large/2000/01/01"
    assert file.name == "MVI_7254.webm"

    [file | files] = files
    assert file.size_key == "orig"
    assert file.width == 480
    assert file.height == 270
    assert file.is_video == true
    assert file.mime_type == "video/webm"
    assert file.dir == "orig/2000/01/01"
    assert file.name == "MVI_7254.webm"

    [] = files

    {:ok, _media} = Media.get_media("#{image_dir}/orig/2000/01/01/MVI_7254.webm")
    {:ok, _media} = Media.get_media("#{image_dir}/thumb/thumb/2000/01/01/MVI_7254.jpg")
    {:ok, _media} = Media.get_media("#{image_dir}/thumb/mid/2000/01/01/MVI_7254.jpg")
    {:ok, _media} = Media.get_media("#{image_dir}/thumb/large/2000/01/01/MVI_7254.jpg")
    {:ok, _media} = Media.get_media("#{image_dir}/thumb/thumb/2000/01/01/MVI_7254.gif")
    {:ok, _media} = Media.get_media("#{image_dir}/thumb/mid/2000/01/01/MVI_7254.gif")
    {:ok, _media} = Media.get_media("#{image_dir}/thumb/large/2000/01/01/MVI_7254.gif")
    {:ok, _media} = Media.get_media("#{image_dir}/video/mid/2000/01/01/MVI_7254.mp4")
    {:ok, _media} = Media.get_media("#{image_dir}/video/large/2000/01/01/MVI_7254.mp4")
    {:ok, _media} = Media.get_media("#{image_dir}/video/mid/2000/01/01/MVI_7254.ogv")
    {:ok, _media} = Media.get_media("#{image_dir}/video/large/2000/01/01/MVI_7254.ogv")
    {:ok, _media} = Media.get_media("#{image_dir}/video/mid/2000/01/01/MVI_7254.webm")
    {:ok, _media} = Media.get_media("#{image_dir}/video/large/2000/01/01/MVI_7254.webm")
  end

  test "upload_file/2 deletes jpg", context do
    image_dir = context[:image_dir]

    album =
      %Album{
        title: "test"
      }
      |> Repo.insert!()

    {:ok, photo} = Upload.upload_file("priv/tests/100x100.jpg", album, date: ~D[2000-01-01])

    # Create image file that will get replaced
    {:ok, media} = Media.get_media("priv/tests/100x100.jpg")
    {:ok, file1} = Storage.build_file_from_media(photo, media, "thumb")

    # Create image file that should get deleted
    file2 = %File{file1 | dir: "special", size_key: "special"}
    mkdir_p!("#{image_dir}/special")
    copy!("priv/tests/100x100.jpg", "#{image_dir}/special/100x100.jpg")

    photo =
      photo
      |> Ecto.Changeset.change()
      |> Ecto.Changeset.put_assoc(:files, [file1, file2 | photo.files])
      |> Repo.update!()

    new_photo = Actions.process_photo(photo)
    %Photo{} = new_photo
    assert length(new_photo.files) == 7

    {:ok, _media} = Media.get_media("#{image_dir}/orig/2000/01/01/100x100.jpg")
    {:ok, _media} = Media.get_media("#{image_dir}/thumb/thumb/2000/01/01/100x100.jpg")
    {:ok, _media} = Media.get_media("#{image_dir}/thumb/mid/2000/01/01/100x100.jpg")
    {:ok, _media} = Media.get_media("#{image_dir}/thumb/large/2000/01/01/100x100.jpg")
    {:ok, _media} = Media.get_media("#{image_dir}/thumb/thumb/2000/01/01/100x100.gif")
    {:ok, _media} = Media.get_media("#{image_dir}/thumb/mid/2000/01/01/100x100.gif")
    {:ok, _media} = Media.get_media("#{image_dir}/thumb/large/2000/01/01/100x100.gif")
    {:error, _} = Media.get_media("#{image_dir}/thumb/special/100x100.jpg")
  end

  test "process_pending/2 works" do
    album =
      %Album{
        title: "test"
      }
      |> Repo.insert!()

    Upload.upload_file("priv/tests/100x100.jpg", album, date: ~D[2000-01-01])
    [new_photo] = Actions.process_pending()
    %Photo{} = new_photo
  end
end
