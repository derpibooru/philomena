defmodule PhilomenaWeb.PaginationView do
  use PhilomenaWeb, :view

  def first_page?(page) do
    page.page_number == 1
  end

  def last_page?(page) do
    page.page_number == page.total_pages
  end

  def page_path(route, params, number) do
    route.([{:page, number} | params])
  end

  def first_page_path(_page, route, params), do: page_path(route, params, 1)
  def prev_page_path(page, route, params), do: page_path(route, params, page.page_number - 1)
  def next_page_path(page, route, params), do: page_path(route, params, page.page_number + 1)
  def last_page_path(page, route, params), do: page_path(route, params, page.total_pages)

  def left_gap?(page) do
    page.page_number >= 5
  end

  def left_page_numbers(page) do
    number = page.page_number
    min = 1
    max = page.total_pages

    (number - 5..number)
    |> Enum.filter(& &1 >= min and &1 != number and &1 <= max)
  end

  def right_gap?(page) do
    page.total_pages - page.page_number >= 5
  end

  def right_page_numbers(page) do
    number = page.page_number
    min = 1
    max = page.total_pages

    (number .. number + 5)
    |> Enum.filter(& &1 >= min and &1 != number and &1 <= max)
  end
end
