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
  alias PenguinMemories.Photos.PhotoRelation
  alias PenguinMemories.Photos.Relation
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
        ccd_width: nil
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

  @spec save_photo(rc()) :: rc()
  # defp save_photo({:error, _} = rc), do: rc
  defp save_photo({:skipped, _} = rc), do: rc

  defp save_photo({:ok, %Photo{} = photo}) do
    rc =
      photo
      |> Ecto.Changeset.change()
      |> Ecto.Changeset.put_assoc(:albums, [])
      |> Ecto.Changeset.put_assoc(:files, [])
      |> Ecto.Changeset.put_assoc(:photo_relations, [])
      |> Repo.insert()

    case rc do
      {:ok, %Photo{}} = rc -> rc
      {:error, %Ecto.Changeset{} = cs} -> {:error, changeset_error_to_string(cs)}
    end
  end

  @spec add_album(rc(), Album.t()) :: rc()
  defp add_album({:error, _} = rc, _), do: rc

  defp add_album({status, %Photo{} = photo}, %Album{} = album) do
    albums = add_item(photo.albums, album, fn a, b -> a.id == b.id end)

    rc =
      photo
      |> Ecto.Changeset.change()
      |> Ecto.Changeset.put_assoc(:albums, albums)
      |> Repo.update()

    case rc do
      {:ok, %Photo{} = photo} -> {status, photo}
      {:error, %Ecto.Changeset{} = cs} -> {:error, changeset_error_to_string(cs)}
    end
  end

  @spec check_file_conflicts(rc(), Media.t(), String.t()) :: rc()
  # defp check_file_conflicts({:error, _, _} = rc, []), do: rc
  # defp check_file_conflicts({:skipped, _, _} = rc, []), do: rc

  defp check_file_conflicts({:ok, %Photo{}} = rc, media, size_key) do
    case Objects.get_file_hash_conflict(media, size_key) do
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

  @spec rollback_if_error(rc()) :: {:ok | :skipped, Photo.t()}
  defp rollback_if_error({:error, _} = rc) do
    Repo.rollback(rc)
  end

  defp rollback_if_error({:skipped, %Photo{}} = rc), do: rc
  defp rollback_if_error({:ok, %Photo{}} = rc), do: rc

  @spec upload_file(String.t(), Album.t(), keyword()) :: rc
  def upload_file(path, album, opts \\ []) do
    {:ok, media} = Media.get_media(path)

    default_date = DateTime.now!("Australia/Melbourne") |> DateTime.to_date()
    upload_date = Keyword.get(opts, :date, default_date)

    timezone = Keyword.get(opts, :timezone, "Australia/Melbourne")
    name = Keyword.get(opts, :name, Path.basename(path))

    exif = Media.get_exif(media)
    offset = get_camera_offset(exif["EXIF:Model"])

    utc_datetime =
      media
      |> Media.get_datetime()
      |> DateTime.from_naive!("Etc/UTC")
      |> DateTime.add(-offset)

    local_datetime = DateTime.shift_zone!(utc_datetime, timezone)

    size_key = "orig"
    photo_dir = Storage.build_photo_dir(upload_date)

    photo = %Photo{
      dir: photo_dir,
      name: name,
      datetime: utc_datetime,
      utc_offset: trunc((local_datetime.utc_offset + local_datetime.std_offset) / 60),
      action: "R"
    }

    photo = add_exif_to_photo(photo, media)

    rc =
      Repo.transaction(fn ->
        {:ok, photo}
        |> check_file_conflicts(media, size_key)
        |> save_photo()
        |> add_album(album)
        |> create_file(media, size_key)
        |> print_status(opts[:verbose], path)
        |> rollback_if_error()
      end)

    case rc do
      {:ok, {:ok, %Photo{}} = rc} ->
        rc

      {:ok, {:skipped, %Photo{}} = rc} ->
        rc

      {:error, {:error, reason}} ->
        {:error, "Error processing #{path}: #{reason}"}
    end
  end

  @spec get_upload_album(String.t()) :: Album.t()
  def get_upload_album(title) do
    parent = Repo.one!(from a in Album, where: a.title == "Uploads")

    case Repo.one(from a in Album, where: a.parent_id == ^parent.id and a.title == ^title) do
      nil ->
        album =
          %Album{
            title: title,
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

  @spec create_relation(list(Photo.t()), String.t()) :: :ok
  defp create_relation(photos, rootname) do
    related_title = "Files for #{rootname}"

    ids = Enum.map(photos, fn photo -> photo.id end)

    {:ok, :ok} =
      Repo.transaction(fn ->
        query =
          from r in Relation,
            join: pr in PhotoRelation,
            on: pr.relation_id == r.id,
            join: p in Photo,
            on: pr.photo_id == p.id,
            where: p.id in ^ids and r.title == ^related_title,
            order_by: [desc: p.id],
            limit: 1

        relation =
          case Repo.one(query) do
            nil ->
              %Relation{
                title: related_title
              }
              |> Repo.insert!()

            relation ->
              relation
          end

        Enum.each(photos, fn photo ->
          pr = %PhotoRelation{
            relation_id: relation.id,
            title: photo.name
          }

          prs =
            add_item(photo.photo_relations, pr, fn a, b ->
              a.relation_id == b.relation_id
            end)

          photo
          |> Ecto.Changeset.change()
          |> Ecto.Changeset.put_assoc(:photo_relations, prs)
          |> Repo.update!()
        end)

        :ok
      end)

    :ok
  end

  @spec upload_group(String.t(), String.t(), list(String.t()), Album.t(), keyword()) ::
          list(Photo.t())
  defp upload_group(directory, rootname, filenames, %Album{} = album, opts) do
    photos =
      Enum.map(filenames, fn filename ->
        path = Path.join(directory, filename)

        if opts[:verbose] do
          IO.puts("---> #{filename}")
        end

        # Do not put this in a transaction here, as if transaction
        # gets rolled back the files will still be created.
        photo =
          case upload_file(path, album, opts) do
            {:ok, %Photo{} = photo} -> photo
            {:skipped, %Photo{} = photo} -> photo
          end

        photo
      end)

    if length(filenames) > 1 do
      create_relation(photos, rootname)
    end

    photos
  end

  @spec upload_directory(String.t(), keyword()) :: list(Photo.t() | nil)
  def upload_directory(directory, opts \\ []) do
    default_date = DateTime.now!("Australia/Melbourne") |> DateTime.to_date()
    upload_date = Keyword.get(opts, :date, default_date)
    opts = Keyword.put(opts, :date, upload_date)

    album =
      directory
      |> Path.basename()
      |> get_upload_album()

    files =
      ls!(directory)
      |> Enum.reject(fn filename ->
        path = Path.join(directory, filename)
        dir?(path)
      end)

    files
    |> Enum.group_by(fn f -> Path.rootname(f) end)
    |> Enum.map(fn {rootname, filenames} ->
      upload_group(directory, rootname, filenames, album, opts)
    end)
    |> List.flatten()
  end
end
