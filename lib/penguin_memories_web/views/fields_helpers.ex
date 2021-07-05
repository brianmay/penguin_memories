defmodule PenguinMemoriesWeb.FieldHelpers do
  @moduledoc """
  Helpers to display Fields and UpdateFields
  """

  use PenguinMemoriesWeb, :view

  alias Phoenix.HTML.Link

  alias PenguinMemories.Database.Fields.Field
  alias PenguinMemories.Database.Fields.UpdateField
  alias PenguinMemories.Database.Query
  alias PenguinMemories.Format
  alias PenguinMemories.Photos

  @spec display_icon(icon :: Query.Icon.t() | nil) :: any()
  defp display_icon(nil), do: ""

  defp display_icon(%Query.Icon{} = icon) do
    display_icons([icon])
  end

  @spec display_icons(icons :: list(Query.Icon.t())) :: any()
  defp display_icons(icons) do
    Phoenix.View.render_to_string(PenguinMemoriesWeb.IncludeView, "list.html",
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

  @spec output_field(obj :: struct(), field :: Field.t()) :: any()
  def output_field(obj, field) do
    value = Map.get(obj, field.id)

    case value do
      nil ->
        nil

      [] ->
        nil

      value ->
        [
          raw("<tr>"),
          raw("<th>"),
          field.name,
          raw("</th>"),
          raw("<td>"),
          output_field_value(obj, value, field),
          raw("</td>"),
          raw("</tr>")
        ]
    end
  end

  @spec output_field_value(obj :: struct(), value :: any(), field :: Field.t()) :: any()
  defp output_field_value(_, nil, _field), do: "N/A"

  defp output_field_value(_, value, %Field{type: {:single, type}}) do
    Query.query_icon_by_id(value.id, type, "thumb")
    |> display_icon()
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
    Link.link("link", to: value)
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

    case field.type do
      :markdown ->
        textarea_input_field(form, field.id, opts)

      {:single, type} ->
        live_component(PenguinMemoriesWeb.ObjectSelectComponent,
          type: type,
          form: form,
          field: field,
          id: field.id,
          disabled: disabled,
          single_choice: true,
          updates: self()
        )

      {:multiple, type} ->
        live_component(PenguinMemoriesWeb.ObjectSelectComponent,
          type: type,
          form: form,
          field: field,
          id: field.id,
          disabled: disabled,
          single_choice: false,
          updates: self()
        )

      :persons ->
        live_component(PenguinMemoriesWeb.PersonsSelectComponent,
          form: form,
          field: field,
          id: field.id,
          disabled: disabled,
          updates: self()
        )

      {:static, _} ->
        nil

      _ ->
        text_input_field(form, field.id, opts)
    end
  end
end
