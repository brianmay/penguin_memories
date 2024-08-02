defmodule PenguinMemories.Upload do
  @moduledoc """
  Upload new media objects
  """
  import Bitwise
  import Ecto.Query
  import File

  alias PenguinMemories.Database.Conflicts
  alias PenguinMemories.Media
  alias PenguinMemories.Photos.Album
  alias PenguinMemories.Photos.File
  alias PenguinMemories.Photos.Photo
  alias PenguinMemories.Repo
  alias PenguinMemories.Storage

  @spec get_camera_offset(String.t()) :: {String.t(), integer()}
  defp get_camera_offset(nil), do: {"Etc/UTC", 0}

  defp get_camera_offset(camera_model) do
    cameras = Application.get_env(:penguin_memories, :cameras)
    {timezone, string} = Map.fetch!(cameras, camera_model)

    [hh, mm, ss] = String.split(string, ":")

    {hh, ""} = Integer.parse(hh)
    {mm, ""} = Integer.parse(mm)
    {ss, ""} = Integer.parse(ss)

    {timezone, (hh * 60 + mm) * 60 + ss}
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
      true -> false
    end
  end

  @spec float(String.t() | integer() | float() | nil) :: float() | nil
  defp float(nil), do: nil

  defp float(number) do
    cond do
      number == "inf" -> nil
      number == "undef" -> nil
      is_nil(number) -> nil
      is_integer(number) -> number * 1.0
      is_float(number) -> number
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

  @spec add_exif_to_photo(Photo.t(), Media.t()) :: Photo.t()
  def add_exif_to_photo(%Photo{} = photo, %Media{} = media) do
    exif = Media.get_exif(media)

    latitude = get(exif, "EXIF:GPSLatitude")
    longitude = get(exif, "EXIF:GPSLongitude")

    point =
      if latitude != nil and longitude != nil do
        %Geo.Point{coordinates: {latitude, longitude}, srid: 4326}
      else
        nil
      end

    %Photo{
      photo
      | camera_make: get(exif, "EXIF:Make"),
        camera_model: get(exif, "EXIF:Model"),
        flash_used: get(exif, "EXIF:Flash") |> flash_used(),
        focal_length: get(exif, "EXIF:FocalLength") |> float(),
        exposure_time: get(exif, "EXIF:ExposureTime") |> float(),
        aperture: get(exif, "EXIF:FNumber") |> float(),
        iso_equiv: get(exif, "EXIF:ISO"),
        metering_mode: get(exif, "EXIF:MeteringMode") |> metering_mode(),
        focus_dist: get(exif, "Composite:HyperfocalDistance") |> float(),
        ccd_width: nil,
        point: point
    }
  end

  @type rc :: {:ok, Photo.t()} | {:skipped, Photo.t()} | {:error, String.t()}

  @spec changeset_error_to_string(Ecto.Changeset.t()) :: String.t()
  defp changeset_error_to_string(%Ecto.Changeset{} = changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Enum.reduce(opts, msg, fn {key, value}, acc ->
        String.replace(acc, "%{#{key}}", to_string(value))
      end)
    end)
    |> Enum.reduce("", fn {k, v}, acc ->
      joined_errors = Enum.join(v, "; ")
      "#{acc}#{k}: #{joined_errors}\n"
    end)
  end

  @spec add_item(list(map()), map(), (map(), map() -> boolean)) :: list(map())
  def add_item([], new_item, _), do: [new_item]

  def add_item([head | tail] = list, new_item, match?) do
    if match?.(head, new_item) do
      list
    else
      [head | add_item(tail, new_item, match?)]
    end
  end

  @spec save_photo(rc(), Album.t()) :: rc()
  # defp save_photo({:error, _} = rc), do: rc
  defp save_photo({:skipped, _} = rc, %Album{}), do: rc

  defp save_photo({:ok, %Photo{} = photo}, %Album{} = album) do
    rc =
      photo
      |> Ecto.Changeset.change()
      |> Ecto.Changeset.put_assoc(:albums, [album])
      |> Ecto.Changeset.put_assoc(:files, [])
      |> Ecto.Changeset.put_assoc(:photo_relations, [])
      |> Repo.insert()

    case rc do
      {:ok, %Photo{}} = rc -> rc
      {:error, %Ecto.Changeset{} = cs} -> {:error, changeset_error_to_string(cs)}
    end
  end

  @spec check_file_conflicts(rc(), Media.t(), String.t()) :: rc()
  # defp check_file_conflicts({:error, _, _} = rc, []), do: rc
  # defp check_file_conflicts({:skipped, _, _} = rc, []), do: rc

  defp check_file_conflicts({:ok, %Photo{}} = rc, media, size_key) do
    case Conflicts.get_file_hash_conflict(media, size_key) do
      nil ->
        rc

      %Photo{} = photo ->
        {:skipped, photo}
    end
  end

  @spec create_file(rc(), Media.t(), String.t()) :: rc()
  defp create_file({:error, _} = rc, _, _), do: rc
  defp create_file({:skipped, _} = rc, _, _), do: rc

  defp create_file({:ok, %Photo{} = photo}, %Media{} = media, size_key) do
    rc = Storage.build_file_from_media(photo, media, size_key, check_conflicts: true)

    case rc do
      {:ok, %File{} = file} ->
        photo =
          photo
          |> Ecto.Changeset.change()
          |> Ecto.Changeset.put_assoc(:files, [file])
          |> Repo.update!()

        {:ok, photo}

      {:error, _} = rc ->
        rc
    end
  end

  @spec print_status(rc(), boolean(), String.t()) :: rc()
  defp print_status({:ok, %Photo{} = photo} = rc, true, _) do
    IO.puts("Done #{Photo.to_string(photo)}")

    Enum.each(photo.files, fn file ->
      IO.puts("     #{File.to_string(file)}")
    end)

    rc
  end

  defp print_status({:skipped, %Photo{} = photo} = rc, true, _) do
    IO.puts("Skipped #{Photo.to_string(photo)}")

    Enum.each(photo.files, fn file ->
      IO.puts("     #{File.to_string(file)}")
    end)

    rc
  end

  defp print_status({:error, reason} = rc, true, path) do
    IO.puts("Error #{path}: #{reason}")
    rc
  end

  defp print_status(rc, _, _), do: rc

  @spec upload_file(String.t(), Album.t(), keyword()) :: rc
  def upload_file(path, album, opts \\ []) do
    {:ok, media} = Media.get_media(path)

    default_date = DateTime.now!("Australia/Melbourne") |> DateTime.to_date()
    upload_date = Keyword.get(opts, :date, default_date)

    timezone = Keyword.get(opts, :timezone, "Australia/Melbourne")
    filename = Keyword.get(opts, :filename, Path.basename(path))

    exif = Media.get_exif(media)
    {file_timezone, offset} = get_camera_offset(exif["EXIF:Model"])

    utc_datetime =
      media
      |> Media.get_datetime()
      |> DateTime.from_naive!(file_timezone)
      |> DateTime.add(-offset)
      |> DateTime.shift_zone!("Etc/UTC")

    local_datetime = DateTime.shift_zone!(utc_datetime, timezone)

    size_key = "orig"
    photo_dir = Storage.build_photo_dir(upload_date)

    photo = %Photo{
      dir: photo_dir,
      filename: filename,
      datetime: utc_datetime,
      utc_offset: trunc((local_datetime.utc_offset + local_datetime.std_offset) / 60),
      action: "R"
    }

    photo = add_exif_to_photo(photo, media)

    rc =
      {:ok, photo}
      |> check_file_conflicts(media, size_key)
      |> save_photo(album)
      |> create_file(media, size_key)
      |> print_status(opts[:verbose], path)

    case rc do
      {:ok, %Photo{}} = rc ->
        rc

      {:skipped, %Photo{}} = rc ->
        rc

      {:error, reason} ->
        {:error, "Error processing #{path}: #{reason}"}
    end
  end

  def get_parent_album() do
    case Repo.one(from a in Album, where: a.name == "Uploads") do
      nil ->
        %Album{name: "Uploads", sort_name: "Uploads"}
        |> Ecto.Changeset.change()
        |> Repo.insert!()

      album ->
        album
    end
  end

  @spec get_upload_album(String.t()) :: Album.t()
  def get_upload_album(name) do
    parent = get_parent_album()

    case Repo.one(from a in Album, where: a.parent_id == ^parent.id and a.name == ^name) do
      nil ->
        album =
          %Album{
            name: name,
            sort_name: name,
            parent_id: parent.id,
            reindex: true
          }
          |> Ecto.Changeset.change()
          |> Repo.insert!()

        album

      %Album{} = album ->
        album
    end
  end

  @spec upload_directory(String.t(), keyword()) :: list(Photo.t())
  def upload_directory(directory, opts \\ []) do
    default_date = DateTime.now!("Australia/Melbourne") |> DateTime.to_date()
    upload_date = Keyword.get(opts, :date, default_date)
    opts = Keyword.put(opts, :date, upload_date)

    album =
      directory
      |> Path.basename()
      |> get_upload_album()

    ls!(directory)
    |> Enum.sort()
    |> Enum.map(fn filename ->
      Path.join(directory, filename)
    end)
    |> Enum.reject(fn path ->
      dir?(path) or Path.extname(path) in [".CR3", ".dng", ".pp3"]
    end)
    |> Enum.map(fn path ->
      case upload_file(path, album, opts) do
        {:ok, %Photo{} = photo} -> photo
        {:skipped, %Photo{} = photo} -> photo
      end
    end)
  end
end
