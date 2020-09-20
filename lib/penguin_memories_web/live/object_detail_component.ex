defmodule PenguinMemoriesWeb.ObjectDetailComponent do
  use PenguinMemoriesWeb, :live_component

  @impl true
  def update(params, socket) do
    type = params.type
    num_selected = MapSet.size(params.selected_ids)

    {selected_object, selected_fields, icons, more_icons} = cond do
      num_selected == 0 ->
        {nil, nil, [], false}
      num_selected == 1 ->
        [id] = MapSet.to_list(params.selected_ids)
        case type.get_details(id) do
          nil -> {nil, nil, [], true}
          {object, icon, fields} -> {object, fields, [icon], false}
        end
      true ->
        limit = 5
        icons = type.get_icons(params.selected_ids, limit)
        fields = type.get_bulk_update_fields()
        {nil, fields, icons, length(icons) >= limit}
    end

    num_found = length(icons)

    assigns = [
      num_selected: num_found,
      selected_object: selected_object,
      selected_fields: selected_fields,
      selected_ids: params.selected_ids,
      more_icons: more_icons,
      icons: icons,
      type: type
    ]
    socket = assign(socket, assigns)
    {:ok, socket}
  end
end
