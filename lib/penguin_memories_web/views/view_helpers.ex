defmodule PenguinMemoriesWeb.ViewHelpers do
  @moduledoc """
  Helpers for all live modules.
  """
  import Phoenix.LiveView
  alias Phoenix.LiveView.Socket

  alias PenguinMemories.Accounts.User
  alias PenguinMemories.Auth
  alias PenguinMemories.Database.Query.Icon

  @spec assign_defaults(socket :: Socket.t(), session :: map()) :: Socket.t()
  def assign_defaults(%Socket{} = socket, session) do
    assigns =
      case Auth.load_user(session) do
        {:ok, %User{} = user} ->
          [current_user: user]

        {:error, _} ->
          [current_user: nil]

        :not_logged_in ->
          [current_user: nil]
      end

    assign(socket, assigns)
  end

  @spec prepend_if(list :: list(), condition :: bool(), item :: any()) :: list()
  def prepend_if(list, condition, item) do
    if condition, do: [item | list], else: list
  end

  @spec lazy_prepend_list_if(list :: list(), condition :: bool(), item :: (() -> list())) ::
          list()
  def lazy_prepend_list_if(list, false, _list_func) do
    list
  end

  def lazy_prepend_list_if(list, true, list_func) do
    items = list_func.()

    Enum.reduce(items, list, fn item, list ->
      [item | list]
    end)
  end

  @spec prepend_list_if(list :: list(), condition :: bool(), items :: list()) :: list()
  def prepend_list_if(list, false, _items) do
    list
  end

  def prepend_list_if(list, true, items) do
    Enum.reduce(items, list, fn item, list ->
      [item | list]
    end)
  end

  @spec icon_classes(Icon.t()) :: list(String.t())
  def icon_classes(%Icon{} = icon) do
    case icon.action do
      "D" -> ["removed"]
      "R" -> ["regenerate"]
      _ -> []
    end
  end
end
