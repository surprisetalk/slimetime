defmodule SlimeTime.ErrorView do
  use SlimeTime.Web, :view

  def render("400.html", _assigns) do
    "Bad input"
  end

  def render("404.html", _assigns) do
    "Page not found"
  end

  def render("500.html", _assigns) do
    "Internal server error"
  end

  def render(msg, _assigns) do
    msg
  end

  # In case no render clause matches or no
  # template is found, let's render it as 500
  def template_not_found(_template, assigns) do
    render "500.html", assigns
  end
end
