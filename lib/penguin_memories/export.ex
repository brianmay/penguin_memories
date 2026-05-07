defmodule PenguinMemories.Export do
  @moduledoc """
  Export photos from an album to a directory on the filesystem.

  Copies the original file (and optionally the raw sidecar) for each photo in
  the specified album to the destination directory. Uses `photo.filename` as
  the output filename. When multiple photos in the same album share the same
  filename, the photo ID is appended to disambiguate.

  ## Usage (from IEx)

      iex> PenguinMemories.Export.export_album(42, "/path/to/export")
      {:ok, %{copied: 100, skipped: 0, errors: 0}}

      iex> PenguinMemories.Export.export_album(42, "/path/to/export", include_raw: true)
      {:ok, %{copied: 150, skipped: 0, errors: 0}}
  """

  alias PenguinMemories.Photos.Album
  alias PenguinMemories.Photos.Photo
  alias PenguinMemories.Photos.PhotoAlbum
  alias PenguinMemories.Repo
  alias PenguinMemories.Storage

  import Ecto.Query
  import File

  require Logger

  @type export_result :: %{
          copied: non_neg_integer(),
          skipped: non_neg_integer(),
          errors: non_neg_integer()
        }

  @doc """
  Export all photos from an album to a destination directory.

  Creates `dest_dir` if it doesn't exist. Copies the "orig" file for every
  photo in the album, using `photo.filename` as the output name. When two or
  more photos share the same filename, each conflicting name is disambiguated
  by inserting `_<photo_id>` before the extension.

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
        preload: [files: ^file_query]

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

    Enum.reduce(photos, initial, fn photo, acc ->
      base_name = Map.fetch!(export_names, photo.id)

      Enum.reduce(photo.files, acc, fn %PenguinMemories.Photos.File{} = file, acc ->
        export_file(photo, file, base_name, dest_dir, acc)
      end)
    end)
  end

  @spec build_export_names(list(Photo.t())) :: %{integer() => String.t()}
  defp build_export_names(photos) do
    photos
    |> Enum.group_by(fn p -> p.filename end)
    |> Enum.flat_map(fn {filename, group} ->
      if length(group) == 1 do
        [{hd(group).id, filename}]
      else
        Enum.map(group, fn p ->
          ext = Path.extname(p.filename)
          base = Path.basename(p.filename, ext)
          {p.id, "#{base}_#{p.id}#{ext}"}
        end)
      end
    end)
    |> Map.new()
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
end
