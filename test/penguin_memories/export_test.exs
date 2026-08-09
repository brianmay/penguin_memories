defmodule PenguinMemories.ExportTest do
  @moduledoc """
  Tests for the export module.
  """

  use PenguinMemories.DataCase

  import File

  alias PenguinMemories.Export
  alias PenguinMemories.Photos.Album
  alias PenguinMemories.Photos.File
  alias PenguinMemories.Photos.Person
  alias PenguinMemories.Photos.Photo
  alias PenguinMemories.Photos.PhotoAlbum
  alias PenguinMemories.Photos.PhotoPerson
  alias PenguinMemories.Storage

  @photo_file "priv/tests/100x100.jpg"

  setup do
    image_dir = Temp.mkdir!()
    Application.put_env(:penguin_memories, :image_dir, image_dir)

    on_exit(fn ->
      rm_rf!(image_dir)
    end)

    {:ok, image_dir: image_dir}
  end

  describe "export_album/3" do
    test "exports photos with zero-padded filenames" do
      dest_dir = Temp.mkdir!()

      album = insert_album!("Album A")
      {photo1, _file} = insert_photo!("IMG_001.JPG", datetime: ~U[2024-01-15 10:30:00Z])
      {photo2, _file} = insert_photo!("IMG_002.JPG", datetime: ~U[2024-01-16 09:00:00Z])
      add_to_album!(album, photo1)
      add_to_album!(album, photo2)

      assert {:ok, %{copied: 2, skipped: 0, errors: 0}} = Export.export_album(album.id, dest_dir)

      assert exists?(Path.join(dest_dir, "#{padded(photo1.id)}#{Path.extname(photo1.filename)}"))
      assert exists?(Path.join(dest_dir, "#{padded(photo2.id)}#{Path.extname(photo2.filename)}"))

      rows = read_index_csv(dest_dir)
      assert length(rows) == 2

      assert index_value(rows, photo1.id, "exported") ==
               "#{padded(photo1.id)}#{Path.extname(photo1.filename)}"

      assert index_value(rows, photo2.id, "exported") ==
               "#{padded(photo2.id)}#{Path.extname(photo2.filename)}"
    end

    test "zero-padded filenames never conflict even for duplicate db filenames" do
      dest_dir = Temp.mkdir!()

      album = insert_album!("Album A")
      {photo1, _file} = insert_photo!("IMG_001.JPG", datetime: ~U[2024-01-15 10:30:00Z])

      {photo2, _file} =
        insert_photo!("IMG_001.JPG", dir: "2000/01/02", datetime: ~U[2024-01-16 09:00:00Z])

      add_to_album!(album, photo1)
      add_to_album!(album, photo2)

      assert {:ok, %{copied: 2, errors: 0}} = Export.export_album(album.id, dest_dir)

      assert exists?(Path.join(dest_dir, "#{padded(photo1.id)}#{Path.extname(photo1.filename)}"))
      assert exists?(Path.join(dest_dir, "#{padded(photo2.id)}#{Path.extname(photo2.filename)}"))
    end

    test "writes index.csv with metadata for each photo" do
      dest_dir = Temp.mkdir!()

      album_a = insert_album!("Album A")
      album_b = insert_album!("Album B")
      person = insert_person!("Alice")

      {photo, _file} =
        insert_photo!("IMG_001.JPG",
          datetime: ~U[2024-01-15 10:30:00Z],
          utc_offset: 600,
          description: "Beach, sunset"
        )

      add_to_album!(album_a, photo)
      add_to_album!(album_b, photo)
      add_person!(photo, person)

      assert {:ok, %{copied: 1, errors: 0}} = Export.export_album(album_a.id, dest_dir)

      rows = read_index_csv(dest_dir)
      assert length(rows) == 1

      row = Enum.at(rows, 0)
      assert row["id"] == Integer.to_string(photo.id)
      assert row["exported"] == "#{padded(photo.id)}#{Path.extname(photo.filename)}"
      assert row["filename"] == "IMG_001.JPG"
      assert row["time"] == "2024-01-15 20:30:00+10:00"
      assert row["description"] == "Beach, sunset"
      assert row["albums"] |> String.split(";") |> Enum.sort() == ["Album A", "Album B"]
      assert row["people"] == "Alice"
    end

    test "include_raw copies raw sidecar with its own extension" do
      dest_dir = Temp.mkdir!()

      album = insert_album!("Album A")
      {photo, _file} = insert_photo!("IMG_001.JPG", datetime: ~U[2024-01-15 10:30:00Z])
      insert_raw_file!(photo, "IMG_001.CR2")
      add_to_album!(album, photo)

      assert {:ok, %{copied: 2, errors: 0}} =
               Export.export_album(album.id, dest_dir, include_raw: true)

      assert exists?(Path.join(dest_dir, "#{padded(photo.id)}#{Path.extname(photo.filename)}"))
      assert exists?(Path.join(dest_dir, "#{padded(photo.id)}.CR2"))

      rows = read_index_csv(dest_dir)
      assert length(rows) == 1
    end

    test "does not copy raw sidecar unless include_raw is set" do
      dest_dir = Temp.mkdir!()

      album = insert_album!("Album A")
      {photo, _file} = insert_photo!("IMG_001.JPG", datetime: ~U[2024-01-15 10:30:00Z])
      insert_raw_file!(photo, "IMG_001.CR2")
      add_to_album!(album, photo)

      assert {:ok, %{copied: 1, errors: 0}} = Export.export_album(album.id, dest_dir)

      assert exists?(Path.join(dest_dir, "#{padded(photo.id)}#{Path.extname(photo.filename)}"))
      refute exists?(Path.join(dest_dir, "#{padded(photo.id)}.CR2"))
    end

    test "returns error for unknown album" do
      assert {:error, "album with id 9999 not found"} = Export.export_album(9999, "/tmp/none")
    end

    test "returns error for album with no photos" do
      dest_dir = Temp.mkdir!()
      album = insert_album!("Empty Album")
      expected_error = "no photos found in album #{album.id}"
      assert {:error, ^expected_error} = Export.export_album(album.id, dest_dir)
    end
  end

  @spec insert_album!(String.t()) :: Album.t()
  defp insert_album!(name) do
    %Album{name: name, sort_name: name}
    |> Repo.insert!()
  end

  @spec insert_person!(String.t()) :: Person.t()
  defp insert_person!(name) do
    %Person{name: name, sort_name: name}
    |> Repo.insert!()
  end

  @spec insert_photo!(String.t(), keyword()) :: {Photo.t(), File.t()}
  defp insert_photo!(filename, opts) do
    datetime = Keyword.get(opts, :datetime, ~U[2024-01-01 12:00:00Z])
    utc_offset = Keyword.get(opts, :utc_offset, 0)
    description = Keyword.get(opts, :description)
    dir = Keyword.get(opts, :dir, "2000/01/01")

    photo =
      %Photo{
        dir: dir,
        filename: filename,
        datetime: datetime,
        utc_offset: utc_offset,
        description: description
      }
      |> Repo.insert!()

    file = create_source_file!(photo, filename, "orig", "image/jpeg")
    {photo, file}
  end

  @spec insert_raw_file!(Photo.t(), String.t()) :: File.t()
  defp insert_raw_file!(photo, filename) do
    create_source_file!(photo, filename, "raw", "image/x-canon-cr2")
  end

  @spec create_source_file!(Photo.t(), String.t(), String.t(), String.t()) :: File.t()
  defp create_source_file!(photo, filename, size_key, mime_type) do
    file_dir = Storage.build_file_dir(photo.dir, size_key, false)
    file_path = Storage.build_path(file_dir, filename)
    mkdir_p!(Storage.build_directory(file_dir))
    copy!(@photo_file, file_path)

    %File{
      size_key: size_key,
      dir: file_dir,
      filename: filename,
      photo_id: photo.id,
      is_video: false,
      mime_type: mime_type,
      width: 100,
      height: 100,
      sha256_hash: <<0>>,
      num_bytes: 0
    }
    |> Repo.insert!()
  end

  @spec add_to_album!(Album.t(), Photo.t()) :: PhotoAlbum.t()
  defp add_to_album!(album, photo) do
    %PhotoAlbum{album_id: album.id, photo_id: photo.id}
    |> Repo.insert!()
  end

  @spec add_person!(Photo.t(), Person.t()) :: PhotoPerson.t()
  defp add_person!(photo, person) do
    %PhotoPerson{photo_id: photo.id, person_id: person.id, position: 0}
    |> Repo.insert!()
  end

  @spec padded(integer()) :: String.t()
  defp padded(id) do
    id |> Integer.to_string() |> String.pad_leading(6, "0")
  end

  @spec read_index_csv(String.t()) :: list(map())
  defp read_index_csv(dest_dir) do
    dest_dir
    |> Path.join("index.csv")
    |> stream!()
    |> CSV.decode!(headers: true)
    |> Enum.to_list()
  end

  @spec index_value(list(map()), integer(), String.t()) :: String.t()
  defp index_value(rows, photo_id, key) do
    row = Enum.find(rows, &(&1["id"] == Integer.to_string(photo_id)))
    row[key]
  end
end
