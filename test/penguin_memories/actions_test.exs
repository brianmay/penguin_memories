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

  @tag :slow
  test "process_photo/1 works jpg", context do
    image_dir = context[:image_dir]

    album =
      %Album{
        name: "test"
      }
      |> Repo.insert!()

    {:ok, photo} = Upload.upload_file("priv/tests/2Y4A3211.JPG", album, date: ~D[2000-01-01])

    filename =
      photo.id
      |> Integer.to_string()
      |> String.pad_leading(8, "0")

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
    assert file.dir == "scaled/thumb/2000/01/01"
    assert file.filename == "#{filename}.gif"

    [file | files] = files
    assert file.size_key == "mid"
    assert file.width == 480
    assert file.height == 320
    assert file.is_video == false
    assert file.mime_type == "image/gif"
    assert file.dir == "scaled/mid/2000/01/01"
    assert file.filename == "#{filename}.gif"

    [file | files] = files
    assert file.size_key == "large"
    assert file.width == 1919
    assert file.height == 1280
    assert file.is_video == false
    assert file.mime_type == "image/gif"
    assert file.dir == "scaled/large/2000/01/01"
    assert file.filename == "#{filename}.gif"

    [file | files] = files
    assert file.size_key == "thumb"
    assert file.width == 120
    assert file.height == 80
    assert file.is_video == false
    assert file.mime_type == "image/jpeg"
    assert file.dir == "scaled/thumb/2000/01/01"
    assert file.filename == "#{filename}.jpg"

    [file | files] = files
    assert file.size_key == "mid"
    assert file.width == 480
    assert file.height == 320
    assert file.is_video == false
    assert file.mime_type == "image/jpeg"
    assert file.dir == "scaled/mid/2000/01/01"
    assert file.filename == "#{filename}.jpg"

    [file | files] = files
    assert file.size_key == "large"
    assert file.width == 1919
    assert file.height == 1280
    assert file.is_video == false
    assert file.mime_type == "image/jpeg"
    assert file.dir == "scaled/large/2000/01/01"
    assert file.filename == "#{filename}.jpg"

    [file | files] = files
    assert file.size_key == "orig"
    assert file.width == 8192
    assert file.height == 5464
    assert file.is_video == false
    assert file.mime_type == "image/jpeg"
    assert file.dir == "orig/2000/01/01"
    assert file.filename == "#{filename}.jpg"

    [] = files

    {:ok, _media} = Media.get_media("#{image_dir}/orig/2000/01/01/#{filename}.jpg")
    {:ok, _media} = Media.get_media("#{image_dir}/scaled/thumb/2000/01/01/#{filename}.jpg")
    {:ok, _media} = Media.get_media("#{image_dir}/scaled/mid/2000/01/01/#{filename}.jpg")
    {:ok, _media} = Media.get_media("#{image_dir}/scaled/large/2000/01/01/#{filename}.jpg")
    {:ok, _media} = Media.get_media("#{image_dir}/scaled/thumb/2000/01/01/#{filename}.gif")
    {:ok, _media} = Media.get_media("#{image_dir}/scaled/mid/2000/01/01/#{filename}.gif")
    {:ok, _media} = Media.get_media("#{image_dir}/scaled/large/2000/01/01/#{filename}.gif")
  end

  @tag :slow
  test "process_photo/1 works webm", context do
    image_dir = context[:image_dir]

    album =
      %Album{
        name: "test"
      }
      |> Repo.insert!()

    {:ok, photo} = Upload.upload_file("priv/tests/MVI_7254.webm", album, date: ~D[2000-01-01])

    filename =
      photo.id
      |> Integer.to_string()
      |> String.pad_leading(8, "0")

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
    assert file.dir == "scaled/thumb/2000/01/01"
    assert file.filename == "#{filename}.gif"

    [file | files] = files
    assert file.size_key == "mid"
    assert file.width == 480
    assert file.height == 270
    assert file.is_video == false
    assert file.mime_type == "image/gif"
    assert file.dir == "scaled/mid/2000/01/01"
    assert file.filename == "#{filename}.gif"

    [file | files] = files
    assert file.size_key == "large"
    assert file.width == 480
    assert file.height == 270
    assert file.is_video == false
    assert file.mime_type == "image/gif"
    assert file.dir == "scaled/large/2000/01/01"
    assert file.filename == "#{filename}.gif"

    [file | files] = files
    assert file.size_key == "thumb"
    assert file.width == 120
    assert file.height == 68
    assert file.is_video == false
    assert file.mime_type == "image/jpeg"
    assert file.dir == "scaled/thumb/2000/01/01"
    assert file.filename == "#{filename}.jpg"

    [file | files] = files
    assert file.size_key == "mid"
    assert file.width == 480
    assert file.height == 270
    assert file.is_video == false
    assert file.mime_type == "image/jpeg"
    assert file.dir == "scaled/mid/2000/01/01"
    assert file.filename == "#{filename}.jpg"

    [file | files] = files
    assert file.size_key == "large"
    assert file.width == 480
    assert file.height == 270
    assert file.is_video == false
    assert file.mime_type == "image/jpeg"
    assert file.dir == "scaled/large/2000/01/01"
    assert file.filename == "#{filename}.jpg"

    [file | files] = files
    assert file.size_key == "thumb"
    assert file.width == 120
    assert file.height == 68
    assert file.is_video == true
    assert file.mime_type == "video/mp4"
    assert file.dir == "scaled/thumb/2000/01/01"
    assert file.filename == "#{filename}.mp4"

    [file | files] = files
    assert file.size_key == "mid"
    assert file.width == 480
    assert file.height == 270
    assert file.is_video == true
    assert file.mime_type == "video/mp4"
    assert file.dir == "scaled/mid/2000/01/01"
    assert file.filename == "#{filename}.mp4"

    [file | files] = files
    assert file.size_key == "large"
    assert file.width == 480
    assert file.height == 270
    assert file.is_video == true
    assert file.mime_type == "video/mp4"
    assert file.dir == "scaled/large/2000/01/01"
    assert file.filename == "#{filename}.mp4"

    [file | files] = files
    assert file.size_key == "thumb"
    assert file.width == 120
    assert file.height == 68
    assert file.is_video == true
    assert file.mime_type == "video/ogg"
    assert file.dir == "scaled/thumb/2000/01/01"
    assert file.filename == "#{filename}.ogv"

    [file | files] = files
    assert file.size_key == "mid"
    assert file.width == 480
    assert file.height == 270
    assert file.is_video == true
    assert file.mime_type == "video/ogg"
    assert file.dir == "scaled/mid/2000/01/01"
    assert file.filename == "#{filename}.ogv"

    [file | files] = files
    assert file.size_key == "large"
    assert file.width == 480
    assert file.height == 270
    assert file.is_video == true
    assert file.mime_type == "video/ogg"
    assert file.dir == "scaled/large/2000/01/01"
    assert file.filename == "#{filename}.ogv"

    [file | files] = files
    assert file.size_key == "thumb"
    assert file.width == 120
    assert file.height == 68
    assert file.is_video == true
    assert file.mime_type == "video/webm"
    assert file.dir == "scaled/thumb/2000/01/01"
    assert file.filename == "#{filename}.webm"

    [file | files] = files
    assert file.size_key == "mid"
    assert file.width == 480
    assert file.height == 270
    assert file.is_video == true
    assert file.mime_type == "video/webm"
    assert file.dir == "scaled/mid/2000/01/01"
    assert file.filename == "#{filename}.webm"

    [file | files] = files
    assert file.size_key == "large"
    assert file.width == 480
    assert file.height == 270
    assert file.is_video == true
    assert file.mime_type == "video/webm"
    assert file.dir == "scaled/large/2000/01/01"
    assert file.filename == "#{filename}.webm"

    [file | files] = files
    assert file.size_key == "orig"
    assert file.width == 480
    assert file.height == 270
    assert file.is_video == true
    assert file.mime_type == "video/webm"
    assert file.dir == "orig/2000/01/01"
    assert file.filename == "#{filename}.webm"

    [] = files

    {:ok, _media} = Media.get_media("#{image_dir}/orig/2000/01/01/#{filename}.webm")
    {:ok, _media} = Media.get_media("#{image_dir}/scaled/thumb/2000/01/01/#{filename}.jpg")
    {:ok, _media} = Media.get_media("#{image_dir}/scaled/mid/2000/01/01/#{filename}.jpg")
    {:ok, _media} = Media.get_media("#{image_dir}/scaled/large/2000/01/01/#{filename}.jpg")
    {:ok, _media} = Media.get_media("#{image_dir}/scaled/thumb/2000/01/01/#{filename}.gif")
    {:ok, _media} = Media.get_media("#{image_dir}/scaled/mid/2000/01/01/#{filename}.gif")
    {:ok, _media} = Media.get_media("#{image_dir}/scaled/large/2000/01/01/#{filename}.gif")
    {:ok, _media} = Media.get_media("#{image_dir}/scaled/mid/2000/01/01/#{filename}.mp4")
    {:ok, _media} = Media.get_media("#{image_dir}/scaled/large/2000/01/01/#{filename}.mp4")
    {:ok, _media} = Media.get_media("#{image_dir}/scaled/mid/2000/01/01/#{filename}.ogv")
    {:ok, _media} = Media.get_media("#{image_dir}/scaled/large/2000/01/01/#{filename}.ogv")
    {:ok, _media} = Media.get_media("#{image_dir}/scaled/mid/2000/01/01/#{filename}.webm")
    {:ok, _media} = Media.get_media("#{image_dir}/scaled/large/2000/01/01/#{filename}.webm")
  end

  @tag :slow
  test "process_photo/1 deletes jpg", context do
    image_dir = context[:image_dir]

    album =
      %Album{
        name: "test"
      }
      |> Repo.insert!()

    {:ok, photo} = Upload.upload_file("priv/tests/100x100.jpg", album, date: ~D[2000-01-01])

    filename =
      photo.id
      |> Integer.to_string()
      |> String.pad_leading(8, "0")

    # Create image file that will get replaced
    {:ok, media} = Media.get_media("priv/tests/100x100.jpg")
    {:ok, file1} = Storage.build_file_from_media(photo, media, "thumb")

    # Create image file that should get deleted
    file2 = %File{file1 | dir: "special", size_key: "special"}
    mkdir_p!("#{image_dir}/special")
    copy!("priv/tests/100x100.jpg", "#{image_dir}/special/#{filename}.jpg")

    photo =
      photo
      |> Ecto.Changeset.change()
      |> Ecto.Changeset.put_assoc(:files, [file1, file2 | photo.files])
      |> Repo.update!()

    new_photo = Actions.process_photo(photo)
    %Photo{} = new_photo
    assert length(new_photo.files) == 7

    {:ok, _media} = Media.get_media("#{image_dir}/orig/2000/01/01/#{filename}.jpg")
    {:ok, _media} = Media.get_media("#{image_dir}/scaled/thumb/2000/01/01/#{filename}.jpg")
    {:ok, _media} = Media.get_media("#{image_dir}/scaled/mid/2000/01/01/#{filename}.jpg")
    {:ok, _media} = Media.get_media("#{image_dir}/scaled/large/2000/01/01/#{filename}.jpg")
    {:ok, _media} = Media.get_media("#{image_dir}/scaled/thumb/2000/01/01/#{filename}.gif")
    {:ok, _media} = Media.get_media("#{image_dir}/scaled/mid/2000/01/01/#{filename}.gif")
    {:ok, _media} = Media.get_media("#{image_dir}/scaled/large/2000/01/01/#{filename}.gif")
    {:error, _} = Media.get_media("#{image_dir}/scaled/special/#{filename}.jpg")
  end

  @tag :slow
  test "process_photo/1 regenerates jpg", context do
    image_dir = context[:image_dir]

    album =
      %Album{
        name: "test"
      }
      |> Repo.insert!()

    {:ok, photo} = Upload.upload_file("priv/tests/100x100.jpg", album, date: ~D[2000-01-01])

    filename =
      photo.id
      |> Integer.to_string()
      |> String.pad_leading(8, "0")

    photo = Actions.process_photo(photo)
    %Photo{} = photo
    assert length(photo.files) == 7

    # Change all generated files to have invalid width and height.
    from(f in File)
    |> where([f], f.size_key != "orig")
    |> Repo.update_all(set: [height: 0, width: 0])

    # Rebuild should fix the width and height.
    photo =
      Photo
      |> Repo.get(photo.id)
      |> Repo.preload(:files)
      |> Ecto.Changeset.change(action: "R")
      |> Repo.update!()

    new_photo = Actions.process_photo(photo)
    %Photo{} = new_photo

    # Check height and width of all files fixed.
    assert false == Enum.any?(new_photo.files, fn file -> file.height == 0 or file.width == 0 end)

    {:ok, _media} = Media.get_media("#{image_dir}/orig/2000/01/01/#{filename}.jpg")
    {:ok, _media} = Media.get_media("#{image_dir}/scaled/thumb/2000/01/01/#{filename}.jpg")
    {:ok, _media} = Media.get_media("#{image_dir}/scaled/mid/2000/01/01/#{filename}.jpg")
    {:ok, _media} = Media.get_media("#{image_dir}/scaled/large/2000/01/01/#{filename}.jpg")
    {:ok, _media} = Media.get_media("#{image_dir}/scaled/thumb/2000/01/01/#{filename}.gif")
    {:ok, _media} = Media.get_media("#{image_dir}/scaled/mid/2000/01/01/#{filename}.gif")
    {:ok, _media} = Media.get_media("#{image_dir}/scaled/large/2000/01/01/#{filename}.gif")
    {:error, _} = Media.get_media("#{image_dir}/scaled/special/#{filename}.jpg")
  end

  @tag :slow
  test "process_photo/1 rotates jpg", context do
    image_dir = context[:image_dir]

    album =
      %Album{
        name: "test"
      }
      |> Repo.insert!()

    {:ok, photo} = Upload.upload_file("priv/tests/2Y4A3211.JPG", album, date: ~D[2000-01-01])

    filename =
      photo.id
      |> Integer.to_string()
      |> String.pad_leading(8, "0")

    # Rebuild should fix the width and height.
    photo =
      Photo
      |> Repo.get(photo.id)
      |> Repo.preload(:files)
      |> Ecto.Changeset.change(action: "90")
      |> Repo.update!()

    new_photo = Actions.process_photo(photo)
    %Photo{} = new_photo

    # Check height and width of all files fixed.
    orig = Enum.filter(new_photo.files, fn file -> file.size_key == "orig" end) |> hd()
    assert orig.width == 5464
    assert orig.height == 8192

    {:ok, media} = Media.get_media("#{image_dir}/orig/2000/01/01/#{filename}.jpg")
    assert Media.get_size(media) == %Media.Size{width: 5464, height: 8192}
  end

  test "process_pending/2 works" do
    album =
      %Album{
        name: "test"
      }
      |> Repo.insert!()

    Upload.upload_file("priv/tests/100x100.jpg", album, date: ~D[2000-01-01])
    [new_photo] = Actions.process_pending()
    %Photo{} = new_photo
  end
end
