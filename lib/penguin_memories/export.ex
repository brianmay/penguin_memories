defmodule PenguinMemories.Export do
  @moduledoc """
  Export photos from an album to a directory on the filesystem.

  Copies the original file (and optionally the raw sidecar) for each photo in
  the specified album to the destination directory. Output filenames are based
  on the photo ID zero-padded to 6 digits (e.g. `042658.jpg`), so exported
  filenames never collide. A `index.csv` file is also written containing basic
  metadata for each exported photo.

  ## Usage (from IEx)

      iex> PenguinMemories.Export.export_album(42, "/path/to/export")
      {:ok, %{copied: 100, skipped: 0, errors: 0}}

      iex> PenguinMemories.Export.export_album(42, "/path/to/export", include_raw: true)
      {:ok, %{copied: 150, skipped: 0, errors: 0}}
  """

  alias PenguinMemories.Format
  alias PenguinMemories.Photos.Album
  alias PenguinMemories.Photos.Photo
  alias PenguinMemories.Photos.PhotoAlbum
  alias PenguinMemories.Repo
  alias PenguinMemories.Storage

  import Ecto.Query
  import File

  require Logger

  @export_padding 6

  @index_headers [:id, :exported, :filename, :time, :description, :albums, :people]

  @type export_result :: %{
          copied: non_neg_integer(),
          skipped: non_neg_integer(),
          errors: non_neg_integer()
        }

  @doc """
  Export all photos from an album to a destination directory.

  Creates `dest_dir` if it doesn't exist. Copies the "orig" file for every
  photo in the album, using a zero-padded photo ID as the output name (e.g.
  `042658.jpg` for photo ID 42658). Raw sidecar files (CR2/CR3) use their own
  extension (e.g. `042658.CR2`). A `index.csv` file is written listing each
  exported photo with its ID, exported filename, database filename, time,
  description, albums and people.

  ## Options

    * `:include_raw` — when `true`, also copies raw sidecar files (CR2/CR3)
      for photos that have them. Defaults to `false`.
  """
  @spec export_album(integer(), String.t(), keyword()) ::
          {:ok, export_result()} | {:error, String.t()}
  def export_album(album_id, dest_dir, opts \\ []) do
    include_raw = Keyword.get(opts, :include_raw, false)

    with {:ok, album} <- get_album(album_id),
         :ok <- ensure_dest_dir(dest_dir),
         {:ok, photo_files} <- load_photo_files(album_id, include_raw) do
      result = do_export(photo_files, dest_dir)
      Logger.info("Exported #{result.copied} files from album \"#{album.name}\" to #{dest_dir}")
      {:ok, result}
    end
  end

  @spec get_album(integer()) :: {:ok, Album.t()} | {:error, String.t()}
  defp get_album(album_id) do
    case Repo.get(Album, album_id) do
      nil -> {:error, "album with id #{album_id} not found"}
      album -> {:ok, album}
    end
  end

  @spec ensure_dest_dir(String.t()) :: :ok | {:error, String.t()}
  defp ensure_dest_dir(dest_dir) do
    case mkdir_p(dest_dir) do
      :ok -> :ok
      {:error, reason} -> {:error, "failed to create destination directory: #{inspect(reason)}"}
    end
  end

  @spec load_photo_files(integer(), boolean()) ::
          {:ok, list(Photo.t())} | {:error, String.t()}
  defp load_photo_files(album_id, include_raw) do
    size_keys = if include_raw, do: ["orig", "raw"], else: ["orig"]

    file_query =
      from f in PenguinMemories.Photos.File,
        where: f.size_key in ^size_keys

    photos =
      from p in Photo,
        join: pa in PhotoAlbum,
        on: pa.photo_id == p.id,
        where: pa.album_id == ^album_id,
        preload: [:albums, :persons, files: ^file_query]

    photo_list = Repo.all(photos)

    if photo_list == [] do
      {:error, "no photos found in album #{album_id}"}
    else
      {:ok, photo_list}
    end
  end

  @spec do_export(list(Photo.t()), String.t()) :: export_result()
  defp do_export(photos, dest_dir) do
    export_names = build_export_names(photos)
    initial = %{copied: 0, skipped: 0, errors: 0}

    result =
      Enum.reduce(photos, initial, fn photo, acc ->
        base_name = Map.fetch!(export_names, photo.id)

        Enum.reduce(photo.files, acc, fn %PenguinMemories.Photos.File{} = file, acc ->
          export_file(photo, file, base_name, dest_dir, acc)
        end)
      end)

    write_index_csv(photos, export_names, dest_dir, result)
  end

  @spec build_export_names(list(Photo.t())) :: %{integer() => String.t()}
  defp build_export_names(photos) do
    Map.new(photos, fn photo -> {photo.id, build_export_name(photo)} end)
  end

  @spec build_export_name(Photo.t()) :: String.t()
  defp build_export_name(%Photo{filename: filename} = photo) do
    extension = Path.extname(filename)
    base = photo.id |> Integer.to_string() |> String.pad_leading(@export_padding, "0")
    base <> extension
  end

  @spec export_file(
          Photo.t(),
          PenguinMemories.Photos.File.t(),
          String.t(),
          String.t(),
          export_result()
        ) :: export_result()
  defp export_file(_photo, %PenguinMemories.Photos.File{} = file, base_name, dest_dir, acc) do
    source_path = Storage.get_photo_file_path(file)

    dest_name =
      if file.size_key == "raw" do
        orig_ext = Path.extname(base_name)
        raw_ext = Path.extname(file.filename)
        Path.basename(base_name, orig_ext) <> raw_ext
      else
        base_name
      end

    dest_path = Path.join(dest_dir, dest_name)
    Logger.info("Copying #{source_path} -> #{dest_path}")

    case cp(source_path, dest_path) do
      :ok ->
        %{acc | copied: acc.copied + 1}

      {:error, reason} ->
        Logger.error("Failed to copy #{source_path}: #{inspect(reason)}")
        %{acc | errors: acc.errors + 1}
    end
  end

  @spec write_index_csv(list(Photo.t()), %{integer() => String.t()}, String.t(), export_result()) ::
          export_result()
  defp write_index_csv(photos, export_names, dest_dir, acc) do
    rows = Enum.map(photos, &index_row(&1, export_names))

    lines =
      rows
      |> CSV.encode(headers: @index_headers, delimiter: "\n", escape_formulas: true)
      |> Enum.to_list()

    index_path = Path.join(dest_dir, "index.csv")

    case File.write(index_path, lines) do
      :ok ->
        Logger.info("Wrote #{index_path}")
        acc

      {:error, reason} ->
        Logger.error("Failed to write #{index_path}: #{inspect(reason)}")
        %{acc | errors: acc.errors + 1}
    end
  end

  @spec index_row(Photo.t(), %{integer() => String.t()}) :: map()
  defp index_row(photo, export_names) do
    %{
      id: photo.id,
      exported: Map.fetch!(export_names, photo.id),
      filename: photo.filename,
      time: Format.display_datetime_offset(photo.datetime, photo.utc_offset),
      description: photo.description,
      albums: join_names(photo.albums),
      people: join_names(photo.persons)
    }
  end

  @spec join_names(Ecto.Association.NotLoaded.t() | list(map())) :: String.t()
  defp join_names(%Ecto.Association.NotLoaded{}), do: ""

  defp join_names(names) when is_list(names) do
    Enum.map_join(names, ";", & &1.name)
  end
end
