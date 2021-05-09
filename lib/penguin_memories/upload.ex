defmodule PenguinMemories.Upload do
  @moduledoc """
  Upload new media objects
  """
  use Bitwise

  import Ecto.Query
  import File

  alias PenguinMemories.Media
  alias PenguinMemories.Objects
  alias PenguinMemories.Photos.Album
  alias PenguinMemories.Photos.File
  alias PenguinMemories.Photos.Photo
  alias PenguinMemories.Repo
  alias PenguinMemories.Storage

  @spec get_camera_offset(String.t()) :: integer()
  defp get_camera_offset(nil), do: 0

  defp get_camera_offset(camera_model) do
    cameras = Application.get_env(:penguin_memories, :cameras)
    string = Map.fetch!(cameras, camera_model)

    [hh, mm, ss] = String.split(string, ":")

    {hh, ""} = Integer.parse(hh)
    {mm, ""} = Integer.parse(mm)
    {ss, ""} = Integer.parse(ss)

    (hh * 60 + mm) * 60 + ss
  end

  @spec metering_mode(integer() | nil) :: String.t()
  defp metering_mode(nil), do: nil

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

  @spec flash_used(integer() | nil) :: boolean() | nil
  defp flash_used(nil), do: nil

  defp flash_used(mode) do
    cond do
      is_nil(mode) -> nil
      (mode &&& 1) != 0 -> true
      True -> false
    end
  end

  @spec exposure(integer() | float() | nil) :: float() | nil
  defp exposure(nil), do: nil

  defp exposure(number) do
    cond do
      is_nil(number) -> nil
      is_integer(number) -> number * 1.0
      True -> number
    end
  end

  @spec get(map(), String.t()) :: any() | nil
  def get(exif, key) do
    case Map.get(exif, key) do
      "" -> nil
      nil -> nil
      value -> value
    end
  end

  @spec upload_file(String.t(), Album.t(), keyword()) ::
          {:ok, Photo.t() | :skipped} | {:error, String.t()}
  def upload_file(path, album, opts \\ []) do
    {:ok, media} = Media.get_media(path)

    upload_date = opts[:date]

    name =
      case opts[:name] do
        nil -> Path.basename(path)
        name -> name
      end

    exif = Media.get_exif(media)
    offset = get_camera_offset(exif["EXIF:Model"])

    datetime =
      media
      |> Media.get_datetime()
      |> DateTime.from_naive!("Etc/UTC")
      |> DateTime.add(-offset)

    size_key = "orig"
    photo_dir = Storage.build_photo_dir(upload_date)

    photo = %Photo{
      camera_make: get(exif, "EXIF:Make"),
      camera_model: get(exif, "EXIF:Model"),
      flash_used: get(exif, "EXIF:Flash") |> flash_used(),
      focal_length: get(exif, "EXIF:FocalLength"),
      exposure: get(exif, "EXIF:ExposureTime"),
      aperture: get(exif, "EXIF:FNumber") |> exposure,
      iso_equiv: get(exif, "EXIF:ISO"),
      metering_mode: get(exif, "EXIF:MeteringMode") |> metering_mode(),
      focus_dist: get(exif, "Composite:HyperfocalDistance"),
      path: photo_dir,
      name: name,
      datetime: datetime,
      # FIXME
      utc_offset: 660,
      action: "R",
      level: 0
    }

    photo_conflicts = Objects.get_photo_path_conflicts(photo_dir, name)
    file_conflicts = Objects.get_file_hash_conflicts(media, size_key)

    with [] <- photo_conflicts,
         [] <- file_conflicts,
         {:ok, file} <-
           Storage.build_file_from_media(photo, media, size_key, check_conflicts: true) do
      photo =
        photo
        |> Ecto.Changeset.change()
        |> Ecto.Changeset.put_assoc(:albums, [album])
        |> Ecto.Changeset.put_assoc(:files, [file])
        |> Repo.insert!()

      if opts[:verbose] do
        IO.puts("Done #{Photo.to_string(photo)}")

        Enum.each(photo.files, fn file ->
          IO.puts("     #{File.to_string(file)}")
        end)
      end

      {:ok, photo}
    else
      {:error, reason} ->
        {:error, reason}

      [_ | _] ->
        pc_string = Enum.map(photo_conflicts, fn p -> Photo.to_string(p) end) |> Enum.join(",")
        fc_string = Enum.map(file_conflicts, fn f -> File.to_string(f) end) |> Enum.join(",")

        if photo_conflicts != [] and opts[:verbose] do
          IO.puts("Skipping #{path} due to photo conflict #{pc_string}")
        end

        if file_conflicts != [] and opts[:verbose] do
          IO.puts("Skipping #{path} due to file conflict #{fc_string}")
        end

        {:ok, :skipped}
    end
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

  @spec upload_directory(String.t(), keyword()) :: list(File.t() | nil)
  def upload_directory(directory, opts \\ []) do
    date =
      case opts[:date] do
        nil -> DateTime.now!("Australia/Melbourne") |> DateTime.to_date()
        date -> date
      end

    album = get_upload_album(date)

    ls!(directory)
    |> Enum.reject(fn filename ->
      path = Path.join(directory, filename)
      dir?(path)
    end)
    |> Enum.map(fn filename ->
      path = Path.join(directory, filename)

      if opts[:verbose] do
        IO.puts("---> #{filename}")
      end

      opts = Keyword.put(opts, :date, date)
      {:ok, _} = upload_file(path, album, opts)
    end)
  end
end
