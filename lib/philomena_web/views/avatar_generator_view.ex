defmodule PhilomenaWeb.AvatarGeneratorView do
  use PhilomenaWeb, :view
  use Bitwise

  alias Philomena.Config

  def generated_avatar(displayed_name) do
    config = config()

    # Generate 8 pseudorandom numbers
    seed = :erlang.crc32(displayed_name)

    {rand, _acc} =
      Enum.map_reduce(1..8, seed, fn _elem, acc ->
        value = xorshift32(acc)
        {value, value}
      end)

    # Set species
    {species, rand} = at(species(config), rand)

    # Set the ranges for the colors we are going to make
    color_range = 128
    color_brightness = 72

    {body_r, body_g, body_b, rand} = rgb(0..color_range, color_brightness, rand)
    {hair_r, hair_g, hair_b, rand} = rgb(0..color_range, color_brightness, rand)
    {style_hr, _rand} = at(all_species(hair_shapes(config), species), rand)

    # Creates bounded hex color strings
    color_bd = format("~2.16.0B~2.16.0B~2.16.0B", [body_r, body_g, body_b])
    color_hr = format("~2.16.0B~2.16.0B~2.16.0B", [hair_r, hair_g, hair_b])

    # Make a character
    avatar_svg(config, color_bd, color_hr, species, style_hr)
  end

  # Build the final SVG for the character.
  #
  # Inputs to raw/1 are not user-generated.
  # sobelow_skip ["XSS.Raw"]
  defp avatar_svg(config, color_bd, color_hr, species, style_hr) do
    [
      header(config),
      background(config),
      for_species(tail_shapes(config), species)["shape"] |> String.replace("HAIR_FILL", color_hr),
      for_species(body_shapes(config), species)["shape"] |> String.replace("BODY_FILL", color_bd),
      style_hr["shape"] |> String.replace("HAIR_FILL", color_hr),
      all_species(extra_shapes(config), species)
      |> Enum.map(&String.replace(&1["shape"], "BODY_FILL", color_bd)),
      footer(config)
    ]
    |> List.flatten()
    |> Enum.map(&raw/1)
  end

  # https://en.wikipedia.org/wiki/Xorshift
  # 32-bit xorshift deterministic PRNG
  defp xorshift32(state) do
    state = state &&& 0xFFFF_FFFF
    state = bxor(state, state <<< 13)
    state = bxor(state, state >>> 17)

    bxor(state, state <<< 5)
  end

  # Generate pseudorandom, clamped RGB values with a specified
  # brightness and random source
  defp rgb(range, brightness, rand) do
    {r, rand} = at(range, rand)
    {g, rand} = at(range, rand)
    {b, rand} = at(range, rand)

    {r + brightness, g + brightness, b + brightness, rand}
  end

  # Pick an element from an enumerable at the specified position,
  # wrapping around as appropriate.
  defp at(list, [position | rest]) do
    length = Enum.count(list)
    position = rem(position, length)

    {Enum.at(list, position), rest}
  end

  defp for_species(styles, species), do: hd(all_species(styles, species))

  defp all_species(styles, species),
    do: Enum.filter(styles, &Enum.member?(&1["species"], species))

  defp format(format_string, args), do: to_string(:io_lib.format(format_string, args))

  defp species(%{"species" => species}), do: species
  defp header(%{"header" => header}), do: header
  defp background(%{"background" => background}), do: background
  defp tail_shapes(%{"tail_shapes" => tail_shapes}), do: tail_shapes
  defp body_shapes(%{"body_shapes" => body_shapes}), do: body_shapes
  defp hair_shapes(%{"hair_shapes" => hair_shapes}), do: hair_shapes
  defp extra_shapes(%{"extra_shapes" => extra_shapes}), do: extra_shapes
  defp footer(%{"footer" => footer}), do: footer

  defp config, do: Config.get(:avatar)
end
