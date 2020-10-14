defmodule PenguinMemoriesWeb.FormHelpers do
  use Phoenix.HTML

  def field_class(form, field, class) do
    errors = form.errors[field]

    case errors do
      nil -> class
      _ -> "#{class} is-not-valid"
    end
  end

  def get_feedback_for(form, field) do
    case form.source.action do
      :update -> nil
      _ -> input_id(form, field)
    end
  end

  defmacro text_input_field(form, field, opts \\ []) do
    quote do
      field_class = field_class(unquote(form), unquote(field), "form-control")
      feedback_for = get_feedback_for(unquote(form), unquote(field))
      {label, opts} = Keyword.pop(unquote(opts), :label)
      opts = [{:class, field_class} | opts]

      content_tag :div, class: "form-group", phx_feedback_for: feedback_for do
        [
          label(unquote(form), unquote(field), label, class: "control-label"),
          text_input(unquote(form), unquote(field), opts),
          error_tag(unquote(form), unquote(field))
        ]
      end
    end
  end

  defmacro textarea_input_field(form, field, opts \\ []) do
    quote do
      field_class = field_class(unquote(form), unquote(field), "form-control")
      feedback_for = get_feedback_for(unquote(form), unquote(field))
      {label, opts} = Keyword.pop(unquote(opts), :label)
      opts = [{:class, field_class} | opts]

      content_tag :div, class: "form-group", phx_feedback_for: feedback_for do
        [
          label(unquote(form), unquote(field), label, class: "control-label"),
          textarea(unquote(form), unquote(field), opts),
          error_tag(unquote(form), unquote(field))
        ]
      end
    end
  end

  defmacro number_input_field(form, field, opts \\ []) do
    quote do
      field_class = field_class(unquote(form), unquote(field), "form-control")
      feedback_for = get_feedback_for(unquote(form), unquote(field))
      {label, opts} = Keyword.pop(unquote(opts), :label)
      opts = [{:class, field_class} | opts]

      content_tag :div, class: "form-group", phx_feedback_for: feedback_for do
        [
          label(unquote(form), unquote(field), label, class: "control-label"),
          number_input(unquote(form), unquote(field), opts),
          error_tag(unquote(form), unquote(field))
        ]
      end
    end
  end

  defmacro select_field(form, field, options, opts \\ []) do
    quote do
      field_class = field_class(unquote(form), unquote(field), "form-control")
      feedback_for = get_feedback_for(unquote(form), unquote(field))
      {label, opts} = Keyword.pop(unquote(opts), :label)
      opts = [{:class, field_class} | opts]

      content_tag :div, class: "form-group", phx_feedback_for: feedback_for do
        [
          label(unquote(form), unquote(field), label, class: "control-label"),
          select(unquote(form), unquote(field), unquote(options), opts),
          error_tag(unquote(form), unquote(field))
        ]
      end
    end
  end

  defmacro password_input_field(form, field, opts \\ []) do
    quote do
      field_class = field_class(unquote(form), unquote(field), "form-control")
      feedback_for = get_feedback_for(unquote(form), unquote(field))
      value = input_value(unquote(form), :password)
      {label, opts} = Keyword.pop(unquote(opts), :label)
      opts = [{:class, field_class}, {:value, value} | opts]

      content_tag :div, class: "form-group", phx_feedback_for: feedback_for do
        [
          label(unquote(form), unquote(field), label, class: "control-label"),
          password_input(unquote(form), unquote(field), opts),
          error_tag(unquote(form), unquote(field))
        ]
      end
    end
  end

  defmacro checkbox_field(form, field, opts \\ []) do
    quote do
      field_class = field_class(unquote(form), unquote(field), "form-check-input")
      feedback_for = get_feedback_for(unquote(form), unquote(field))
      {label, opts} = Keyword.pop(unquote(opts), :label)
      opts = [{:class, field_class} | opts]

      content_tag :div, class: "form-group form-check", phx_feedback_for: feedback_for do
        [
          checkbox(unquote(form), unquote(field), opts),
          label(unquote(form), unquote(field), label, class: "control-label"),
          error_tag(unquote(form), unquote(field))
        ]
      end
    end
  end
end
