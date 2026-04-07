defmodule PenguinMemoriesWeb.FieldHelpers do
  @moduledoc """
  Helpers to display Fields and UpdateFields
  """

  use PenguinMemoriesWeb, :html

  alias PenguinMemories.Auth
  alias PenguinMemories.Auth.User
  alias PenguinMemories.Database.Fields.Field
  alias PenguinMemories.Database.Fields.UpdateField
  alias PenguinMemories.Database.Query
  alias PenguinMemories.Format
  alias PenguinMemories.Photos
  alias PenguinMemories.Photos.AlbumParent
  alias PenguinMemories.Repo

  @spec display_icon(icon :: Query.Icon.t() | nil) :: any()
  defp display_icon(nil), do: ""

  defp display_icon(%Query.Icon{} = icon) do
    display_icons([icon])
  end

  @spec display_icons(icons :: list(Query.Icon.t())) :: any()
  defp display_icons(icons) do
    render_to_string(PenguinMemoriesWeb.IncludeView, "list.html",
      icons: icons,
      classes: [],
      event: "goto"
    )
    |> raw()
  end

  @spec display_markdown(value :: String.t() | nil) :: any()
  defp display_markdown(nil), do: []

  defp display_markdown(value) do
    case Earmark.as_html(value) do
      {:ok, html_doc, _} ->
        Phoenix.HTML.raw(html_doc)

      {:error, _, errors} ->
        result = ["</ul>"]

        result =
          Enum.reduce(errors, result, fn {_, _, text}, acc ->
            ["<li>", text, "</li>" | acc]
          end)

        result = ["<ul class='alert alert-danger'>" | result]
        Phoenix.HTML.raw(result)
    end
  end

  @spec display_album_parents_table(album_parents :: list(AlbumParent.t())) :: any()
  defp display_album_parents_table([]), do: ""

  defp display_album_parents_table(album_parents) do
    table_html =
      """
      <div class="table-responsive">
      <table class="album-parents-table table table-striped table-sm">
      <thead>
        <tr>
          <th>Parent Album</th>
          <th>You appear as</th>
          <th>Sort Name</th>
          <th>Cover Photo</th>
        </tr>
      </thead>
      <tbody>
      """ <>
        Enum.map_join(album_parents, "", &render_album_parent_row/1) <>
        """
          </tbody>
        </table>
        </div>
        """

    {:wide, raw(table_html)}
  end

  @spec render_album_parent_row(album_parent :: AlbumParent.t()) :: String.t()
  defp render_album_parent_row(album_parent) do
    parent_name =
      if album_parent.parent do
        album_parent.parent.name
      else
        "Album #{album_parent.parent_id}"
      end

    context_name = album_parent.context_name || "-"
    context_sort_name = album_parent.context_sort_name || "-"

    # Handle cover photo display
    cover_photo_display =
      if album_parent.context_cover_photo_id do
        "Photo #{album_parent.context_cover_photo_id}"
      else
        "-"
      end

    # Safely escape HTML content
    safe_parent_name = Plug.HTML.html_escape(parent_name)
    safe_context_name = Plug.HTML.html_escape(context_name)
    safe_context_sort_name = Plug.HTML.html_escape(context_sort_name)
    safe_cover_photo_display = Plug.HTML.html_escape(cover_photo_display)

    """
      <tr class="album-parent-row" 
          phx-click="goto" 
          phx-value-type="album" 
          phx-value-id="#{album_parent.parent_id}"
          style="cursor: pointer;">
        <td class="parent-name">#{safe_parent_name}</td>
        <td class="context-name">#{safe_context_name}</td>
        <td class="context-sort-name">#{safe_context_sort_name}</td>
        <td class="cover-photo">#{safe_cover_photo_display}</td>
      </tr>
    """
  end

  @spec output_field(user :: User.t(), obj :: struct(), field :: Field.t()) :: any()
  def output_field(user, obj, field) do
    value = Map.get(obj, field.id)

    case value do
      nil ->
        nil

      [] ->
        nil

        nil

      value ->
        show_field =
          case field do
            %Field{type: :geo_point} ->
              # Use unified geo point authorization
              Auth.can_see_geo_point(user, value)

            _ ->
              # For other field types, always show (non-geographic fields are public)
              true
          end

        if show_field do
          case output_field_value(obj, value, field) do
            {:wide, rendered} ->
              # Wide fields (e.g. album-parents table) span both columns so
              # they are not constrained by the fixed-layout label column.
              [
                raw("<tr>"),
                raw("<th colspan=\"2\">"),
                field.name,
                raw("</th>"),
                raw("</tr>"),
                raw("<tr>"),
                raw("<td colspan=\"2\">"),
                rendered,
                raw("</td>"),
                raw("</tr>")
              ]

            rendered ->
              [
                raw("<tr>"),
                raw("<th>"),
                field.name,
                raw("</th>"),
                raw("<td>"),
                rendered,
                raw("</td>"),
                raw("</tr>")
              ]
          end
        else
          nil
        end
    end
  end

  @spec output_field_value(obj :: struct(), value :: any(), field :: Field.t()) :: any()
  defp output_field_value(_, nil, _field), do: "N/A"

  defp output_field_value(_, value, %Field{type: {:single, type}}) do
    Query.query_icon_by_id(value.id, type, "thumb")
    |> display_icon()
  end

  defp output_field_value(_, value, %Field{id: :album_children, type: {:multiple, AlbumParent}}) do
    # For children: show child albums with their context names
    # Preload the album association to get the actual album names when context_name is nil
    value = Repo.preload(value, :album)

    value
    |> Enum.map(fn album_parent ->
      # Use context_name if available, otherwise fall back to the actual album name
      display_name =
        album_parent.context_name ||
          (album_parent.album && album_parent.album.name) ||
          "Album #{album_parent.album_id}"

      %Query.Icon{
        id: album_parent.album_id,
        action: nil,
        url: "/album/#{album_parent.album_id}",
        name: display_name,
        subtitle: nil,
        details: nil,
        width: 0,
        height: 0,
        type: Photos.Album
      }
    end)
    |> display_icons()
  end

  defp output_field_value(_, value, %Field{id: :album_parents, type: {:multiple, AlbumParent}}) do
    # For parents: show parent albums with context information in a table format
    # Note: album_parent.context_name represents how the CHILD appears in the parent context
    display_album_parents_table(value)
  end

  defp output_field_value(_, value, %Field{type: {:multiple, AlbumParent}}) do
    # Fallback for other AlbumParent fields (shouldn't be reached with current setup)
    value = Repo.preload(value, :album)

    value
    |> Enum.map(fn album_parent ->
      # Use context_name if available, otherwise fall back to the actual album name
      display_name =
        album_parent.context_name ||
          (album_parent.album && album_parent.album.name) ||
          "Album #{album_parent.album_id}"

      %Query.Icon{
        id: album_parent.album_id,
        action: nil,
        url: "/album/#{album_parent.album_id}",
        name: display_name,
        subtitle: nil,
        details: nil,
        width: 0,
        height: 0,
        type: Photos.Album
      }
    end)
    |> display_icons()
  end

  defp output_field_value(_, value, %Field{type: {:multiple, type}}) do
    value
    |> Enum.map(fn obj -> obj.id end)
    |> Enum.into(MapSet.new())
    |> Query.query_icons_by_id_map(10, type, "thumb")
    |> display_icons()
  end

  defp output_field_value(_, value, %Field{type: :markdown}) do
    display_markdown(value)
  end

  defp output_field_value(_, value, %Field{type: :datetime}) do
    Format.display_datetime(value)
  end

  defp output_field_value(_, value, %Field{type: :date}) do
    Format.display_date(value)
  end

  defp output_field_value(obj, value, %Field{type: {:datetime_with_offset, utc_offset_field}}) do
    utc_offset = Map.get(obj, utc_offset_field)
    Format.display_datetime_offset(value, utc_offset)
  end

  defp output_field_value(_, value, %Field{type: :persons}) do
    icons =
      value
      |> Enum.map(fn obj -> obj.person_id end)
      |> MapSet.new()
      |> Query.query_icons_by_id_map(100, Photos.Person, "thumb")
      |> Enum.map(fn icon -> {icon.id, icon} end)
      |> Enum.into(%{})

    value
    |> Enum.map(fn obj -> obj.person_id end)
    |> Enum.map(fn id -> Map.get(icons, id) end)
    |> Enum.reject(fn icon -> is_nil(icon) end)
    |> display_icons()
  end

  defp output_field_value(_, related, %Field{type: :related}) do
    icons =
      Enum.map(related, fn result -> result.pr.photo_id end)
      |> MapSet.new()
      |> Query.query_icons_by_id_map(100, Photos.Photo, "thumb")
      |> Enum.map(fn icon -> {icon.id, icon} end)
      |> Enum.into(%{})

    related_icons =
      Enum.map(related, fn result ->
        icon = Map.get(icons, result.pr.photo_id)
        icon = %Query.Icon{icon | name: result.pr.name, subtitle: nil, action: nil}
        Map.put(result, :icon, icon)
      end)
      |> Enum.group_by(fn value -> value.r end, fn value -> value.icon end)

    Enum.map(related_icons, fn {related, icons} ->
      [
        raw("<div class='related'>"),
        raw("<div class='name'>"),
        related.name,
        raw("</div>"),
        raw("<div class='description'>"),
        display_markdown(related.description),
        raw("</div>"),
        display_icons(icons),
        raw("</div>")
      ]
    end)
  end

  defp output_field_value(_, value, %Field{type: :url}) do
    link("link", to: value)
  end

  defp output_field_value(_, value, %Field{type: :geo_point}) do
    {lat, lng} = value.coordinates
    link = "https://maps.google.com/?q=#{lat},#{lng}"

    [
      "Latitude: ",
      Float.to_string(lat),
      raw("</br>"),
      "Longitude: ",
      Float.to_string(lng),
      raw("</br>"),
      link("link", to: link)
    ]
  end

  defp output_field_value(_, value, _field) when is_integer(value) do
    Integer.to_string(value)
  end

  defp output_field_value(_, value, _field) when is_float(value) do
    :io_lib.format("~f", [value])
    # use to_string instead of Enum.at(0) which returns charlist
    |> to_string()
  end

  defp output_field_value(_, value, _field) when is_boolean(value) do
    to_string(value)
  end

  defp output_field_value(_, value, _field) when is_binary(value) do
    value
  end

  @spec input_field(
          Phoenix.HTML.Form.t(),
          Field.t() | UpdateField.t(),
          keyword()
        ) :: any()
  def input_field(form, field, opts \\ []) do
    opts = [{:label, field.name} | opts]
    disabled = Keyword.get(opts, :disabled, false)

    case field do
      # Special case for album parents with context editing
      %{id: :album_parents_edit} ->
        live_component(%{
          module: PenguinMemoriesWeb.AlbumParentContextComponent,
          form: form,
          field: field,
          id: field.id,
          disabled: disabled,
          search: %{},
          updates: self()
        })

      _ ->
        case field.type do
          :markdown ->
            textarea_input_field(form, field.id, opts)

          {:single, type} ->
            live_component(%{
              module: PenguinMemoriesWeb.ObjectSelectComponent,
              type: type,
              form: form,
              field: field,
              id: field.id,
              disabled: disabled,
              single_choice: true,
              updates: self()
            })

          {:multiple, type} ->
            live_component(%{
              module: PenguinMemoriesWeb.ObjectSelectComponent,
              type: type,
              form: form,
              field: field,
              id: field.id,
              disabled: disabled,
              single_choice: false,
              updates: self()
            })

          :persons ->
            live_component(%{
              module: PenguinMemoriesWeb.PersonsSelectComponent,
              form: form,
              field: field,
              id: field.id,
              disabled: disabled,
              updates: self()
            })

          {:static, _} ->
            nil

          _ ->
            text_input_field(form, field.id, opts)
        end
    end
  end
end
