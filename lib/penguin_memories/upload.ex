defmodule PenguinMemories.Upload do
  @moduledoc """
  Upload new media objects
  """
  use Bitwise

  import Ecto.Query

  alias File, as: OsFile

  alias PenguinMemories.Media
  alias PenguinMemories.Objects
  alias PenguinMemories.Photos.Album
  alias PenguinMemories.Photos.File, as: PFile
  alias PenguinMemories.Photos.Photo
  alias PenguinMemories.Repo
  alias PenguinMemories.Storage

  @spec get_camera_offset(String.t()) :: integer()
  defp get_camera_offset(camera_model) do
    string = Application.get_env(:penguin_memories, :cameras)[camera_model]

    [hh, mm, ss] = String.split(string, ":")

    {hh, ""} = Integer.parse(hh)
    {mm, ""} = Integer.parse(mm)
    {ss, ""} = Integer.parse(ss)

    (hh * 60 + mm) * 60 + ss
  end

  @spec metering_mode(integer()) :: String.t()
  defp metering_mode(mode) do
    modes = %{
      0 => "unknown",
      1 => "average",
      2 => "center weighted average",
      3 => "spot",
      4 => "multi spot",
      5 => "pattern",
      6 => "partial",
      255 => "other"
    }

    Map.get(modes, mode, "reserved")
  end

  @spec upload_file(String.t(), Album.t(), keyword()) :: Photo.t()
  def upload_file(path, album, attrs) do
    {:ok, media} = Media.get_media(path)

    upload_date = attrs[:date]

    name =
      case attrs[:name] do
        nil -> Path.basename(path)
        name -> name
      end

    size = Media.get_size(media)
    sha256_hash = Media.get_sha256_hash(media)
    num_bytes = Media.get_num_bytes(media)
    format = Media.get_format(media)
    is_video = Media.is_video(media)
    exif = Media.get_exif(media)
    offset = get_camera_offset(exif["EXIF:Model"])

    datetime =
      media
      |> Media.get_datetime()
      |> DateTime.from_naive!("Etc/UTC")
      |> DateTime.add(-offset)

    size_key = "orig"
    photo_dir = Storage.build_photo_dir(upload_date)
    file_dir = Storage.build_file_dir(photo_dir, size_key, is_video)

    [] = Objects.get_photo_conflicts(photo_dir, name)
    [] = Objects.get_file_conflicts(file_dir, name, size_key, num_bytes, sha256_hash)

    dest_directory = Storage.build_directory(file_dir)
    dest_path = Storage.build_filename(file_dir, name)
    false = OsFile.exists?(dest_path)

    OsFile.mkdir_p!(dest_directory)
    OsFile.copy!(path, dest_path)

    file = %PFile{
      size_key: size_key,
      width: size.width,
      height: size.height,
      dir: file_dir,
      name: name,
      is_video: is_video,
      mime_type: format,
      sha256_hash: sha256_hash,
      num_bytes: num_bytes
    }

    flash_used = if (exif["EXIF:Flash"] &&& 1) != 0, do: "Y", else: "N"

    photo = %Photo{
      camera_make: exif["EXIF:Make"],
      camera_model: exif["EXIF:Model"],
      flash_used: flash_used,
      focal_length: "#{exif["EXIF:FocalLength"]}",
      exposure: "#{exif["EXIF:ExposureTime"]}",
      aperture: "f/#{exif["EXIF:FNumber"]}",
      iso_equiv: "#{exif["EXIF:ISO"]}",
      metering_mode: metering_mode(exif["EXIF:MeteringMode"]),
      focus_dist: "#{exif["Composite:HyperfocalDistance"]}",
      path: photo_dir,
      name: name,
      datetime: datetime,
      # FIXME
      utc_offset: 660,
      action: "R",
      level: 0
    }

    photo
    |> Ecto.Changeset.change()
    |> Ecto.Changeset.put_assoc(:albums, [album])
    |> Ecto.Changeset.put_assoc(:files, [file])
    |> Repo.insert!()
  end

  @spec get_upload_album(Date.t()) :: Album.t()
  def get_upload_album(date) do
    parent = Repo.one!(from a in Album, where: a.title == "Uploads")

    title = Date.to_iso8601(date)

    case Repo.one(from a in Album, where: a.parent_id == ^parent.id and a.title == ^title) do
      nil ->
        album =
          %Album{
            title: title,
            sort_name: "Date",
            sort_order: title,
            parent_id: parent.id
          }
          |> Ecto.Changeset.change()
          |> Repo.insert!()

        Objects.fix_index_tree(album.id, PenguinMemories.Objects.Album)
        album

      %Album{} = album ->
        album
    end
  end

  def upload_directory(directory) do
    date = DateTime.now!("Australia/Melbourne") |> DateTime.to_date()
    album = get_upload_album(date)

    File.ls!(directory)
    |> Enum.map(fn filename ->
      IO.puts("---> #{filename}")
      path = Path.join(directory, filename)
      upload_file(path, album, date: date)
    end)
  end
end
