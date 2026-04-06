defmodule PenguinMemoriesWeb.UploadLive do
  @moduledoc """
  LiveView for uploading photos from the browser.

  Users select a directory (via webkitdirectory) or individual files.
  Files are streamed to the server as soon as they are selected (auto_upload:
  true), showing per-file progress bars. Once all transfers are complete the
  user clicks Upload, which triggers the server-side DB / file-copy work.

  Processing runs in a background Task so the LiveView stays responsive.
  Each completed file sends a {:file_result, result} message back to the
  LiveView process, which appends it to the results list in real time.

  The upload is idempotent: re-uploading the same directory skips already-
  imported files (SHA-256 / num_bytes dedup).
  """

  use PenguinMemoriesWeb, :live_view

  require Logger

  alias PenguinMemories.Auth
  alias PenguinMemories.Upload
  alias PenguinMemories.Urls

  # Maximum individual file size accepted by the LiveView upload slot.
  # RAW files (CR2/CR3) can be 30–80 MB. Set to 200 MB to be safe.
  @max_file_size 200 * 1_024 * 1_024

  # Extensions treated as primary photo files (not sidecars).
  # Must be lowercase with a known MIME type (LiveView allow_upload requirement).
  @primary_extensions ~w(.jpg .jpeg .png .mp4 .mov .avi)

  # Extensions treated as raw/sidecar files.
  @sidecar_extensions ~w(.cr2 .cr3 .dng)

  @all_extensions @primary_extensions ++ @sidecar_extensions

  # ---------------------------------------------------------------------------
  # Mount
  # ---------------------------------------------------------------------------

  @impl true
  def mount(_params, _session, socket) do
    socket =
      socket
      |> assign(
        active: "upload",
        page_title: "Upload Photos",
        album_name: "",
        auto_rotate: false,
        # :idle | :transferring | :processing | :done
        status: :idle,
        results: [],
        pending: 0,
        error: nil
      )
      |> allow_upload(:photos,
        accept: @all_extensions,
        max_entries: 5_000,
        max_file_size: @max_file_size,
        # Start transferring to the server as soon as files are selected,
        # so progress bars are meaningful and all data is ready when the
        # user clicks Upload.
        auto_upload: true
      )

    {:ok, socket}
  end

  @impl true
  def handle_params(_params, uri, socket) do
    url = Urls.parse_url(uri)
    {:noreply, assign(socket, url: url)}
  end

  # ---------------------------------------------------------------------------
  # Events
  # ---------------------------------------------------------------------------

  @impl true
  def handle_event("validate", %{"upload" => params}, socket) do
    album_name = Map.get(params, "album_name", socket.assigns.album_name)
    auto_rotate = Map.get(params, "auto_rotate", "false") == "true"
    {:noreply, assign(socket, album_name: album_name, auto_rotate: auto_rotate)}
  end

  def handle_event("validate", _params, socket) do
    {:noreply, socket}
  end

  def handle_event("cancel-upload", %{"ref" => ref}, socket) do
    {:noreply, cancel_upload(socket, :photos, ref)}
  end

  def handle_event("upload", _params, socket) do
    user = socket.assigns[:current_user]

    unless Auth.can_edit(user) do
      {:noreply, assign(socket, error: "You must be logged in to upload photos.")}
    else
      album_name = String.trim(socket.assigns.album_name)
      auto_rotate = socket.assigns.auto_rotate

      cond do
        album_name == "" ->
          {:noreply, assign(socket, error: "Please enter an album name.")}

        Enum.empty?(socket.assigns.uploads.photos.entries) ->
          {:noreply, assign(socket, error: "No files selected.")}

        not all_transfers_complete?(socket) ->
          {:noreply, assign(socket, error: "Please wait for all files to finish transferring.")}

        true ->
          start_processing(socket, album_name, auto_rotate)
      end
    end
  end

  # ---------------------------------------------------------------------------
  # Background task messages
  # ---------------------------------------------------------------------------

  @impl true
  def handle_info({:file_result, result}, socket) do
    results = socket.assigns.results ++ [result]
    pending = max(socket.assigns.pending - 1, 0)

    status = if pending == 0, do: :done, else: :processing

    socket =
      socket
      |> assign(results: results, pending: pending, status: status)
      |> then(fn s ->
        if status == :done, do: put_flash(s, :info, build_summary(results)), else: s
      end)

    {:noreply, socket}
  end

  def handle_info({:processing_error, reason}, socket) do
    {:noreply, assign(socket, status: :done, error: "Processing failed: #{reason}")}
  end

  # ---------------------------------------------------------------------------
  # Private helpers
  # ---------------------------------------------------------------------------

  @spec all_transfers_complete?(Phoenix.LiveView.Socket.t()) :: boolean()
  defp all_transfers_complete?(socket) do
    Enum.all?(socket.assigns.uploads.photos.entries, & &1.done?)
  end

  @spec start_processing(Phoenix.LiveView.Socket.t(), String.t(), boolean()) ::
          {:noreply, Phoenix.LiveView.Socket.t()}
  defp start_processing(socket, album_name, auto_rotate) do
    lv_pid = self()

    # Consume all completed entries into a dedicated temp directory that we
    # own. LiveView cleans up its own tmp dir after consume_uploaded_entries
    # returns, so we must copy the files somewhere we control before handing
    # off to the background task.
    tmp_dir = Temp.mkdir!("pm_upload_")

    file_pairs =
      consume_uploaded_entries(socket, :photos, fn %{path: tmp_path}, entry ->
        dest = Path.join(tmp_dir, entry.client_name)
        File.cp!(tmp_path, dest)
        {:ok, {entry.client_name, dest}}
      end)

    # Group by base name so CR2/CR3 sidecars pair with their primary file.
    file_groups =
      Enum.group_by(file_pairs, fn {name, _path} ->
        name |> Path.basename() |> Path.rootname() |> String.downcase()
      end)

    pending = map_size(file_groups)

    Task.start(fn ->
      try do
        album = Upload.get_upload_album(album_name)
        opts = [verbose: false, auto_rotate: auto_rotate]

        Enum.each(file_groups, fn {_base, files} ->
          result = process_file_group(files, album, opts)
          send(lv_pid, {:file_result, result})
        end)
      rescue
        e ->
          send(lv_pid, {:processing_error, Exception.message(e)})
      after
        File.rm_rf(tmp_dir)
      end
    end)

    socket =
      assign(socket,
        status: :processing,
        results: [],
        pending: pending,
        error: nil,
        album_name: ""
      )

    {:noreply, socket}
  end

  # Given a group of files sharing the same base name, determine which is
  # primary (JPG/video) and which is a sidecar (CR2/CR3), then call
  # Upload.upload_file for the primary. Sidecars are copied alongside the
  # primary in the same tmp dir so add_raw_files can locate them by extension.
  @spec process_file_group(list({String.t(), String.t()}), term(), keyword()) ::
          %{name: String.t(), status: atom(), detail: String.t()}
  defp process_file_group(files, album, opts) do
    lowered_primary_exts = Enum.map(@primary_extensions, &String.downcase/1)

    {primaries, sidecars} =
      Enum.split_with(files, fn {name, _path} ->
        String.downcase(Path.extname(name)) in lowered_primary_exts
      end)

    case primaries do
      [] ->
        # Only sidecars — upload the first one directly as orig.
        [{name, path} | _] = sidecars
        do_upload_file(path, name, album, opts)

      [{name, primary_path} | _] ->
        # Copy sidecars alongside the primary so add_raw_files finds them.
        base = Path.basename(name, Path.extname(name))
        tmp_dir = Path.dirname(primary_path)

        Enum.each(sidecars, fn {sidecar_name, sidecar_path} ->
          ext = Path.extname(sidecar_name)
          dest = Path.join(tmp_dir, base <> ext)

          unless sidecar_path == dest do
            File.cp!(sidecar_path, dest)
          end
        end)

        do_upload_file(primary_path, name, album, opts)
    end
  end

  @spec do_upload_file(String.t(), String.t(), term(), keyword()) ::
          %{name: String.t(), status: atom(), detail: String.t()}
  defp do_upload_file(path, original_name, album, opts) do
    opts = Keyword.put(opts, :filename, original_name)

    case Upload.upload_file(path, album, opts) do
      {:ok, photo} ->
        %{name: original_name, status: :ok, detail: "Imported (id #{photo.id})"}

      {:skipped, photo} ->
        %{name: original_name, status: :skipped, detail: "Already imported (id #{photo.id})"}

      {:error, reason} ->
        Logger.error("Upload failed for #{original_name}: #{inspect(reason)}")
        %{name: original_name, status: :error, detail: to_string(reason)}
    end
  end

  @spec build_summary(list(map())) :: String.t()
  defp build_summary(results) do
    ok = Enum.count(results, &(&1.status == :ok))
    skipped = Enum.count(results, &(&1.status == :skipped))
    errors = Enum.count(results, &(&1.status == :error))

    parts = []
    parts = if ok > 0, do: ["#{ok} imported" | parts], else: parts
    parts = if skipped > 0, do: ["#{skipped} skipped" | parts], else: parts
    parts = if errors > 0, do: ["#{errors} errors" | parts], else: parts

    Enum.join(parts, ", ")
  end

  # ---------------------------------------------------------------------------
  # Template helpers (called from upload_live.html.heex)
  # ---------------------------------------------------------------------------

  @spec error_to_string(atom()) :: String.t()
  def error_to_string(:too_large), do: "File is too large (max 200 MB)"
  def error_to_string(:not_accepted), do: "File type not accepted"
  def error_to_string(:too_many_files), do: "Too many files selected"
  def error_to_string(err), do: "Upload error: #{inspect(err)}"

  @spec format_bytes(integer()) :: String.t()
  def format_bytes(bytes) when bytes < 1_024, do: "#{bytes} B"
  def format_bytes(bytes) when bytes < 1_048_576, do: "#{Float.round(bytes / 1_024, 1)} KB"

  def format_bytes(bytes) when bytes < 1_073_741_824,
    do: "#{Float.round(bytes / 1_048_576, 1)} MB"

  def format_bytes(bytes), do: "#{Float.round(bytes / 1_073_741_824, 2)} GB"

  @spec result_row_class(atom()) :: String.t()
  def result_row_class(:ok), do: "table-success"
  def result_row_class(:skipped), do: "table-secondary"
  def result_row_class(:error), do: "table-danger"
  def result_row_class(_), do: ""

  @spec result_badge(atom()) :: String.t()
  def result_badge(:ok), do: "Imported"
  def result_badge(:skipped), do: "Skipped"
  def result_badge(:error), do: "Error"
  def result_badge(s), do: to_string(s)
end
