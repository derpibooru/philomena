defmodule Philomena.Captcha do
  defstruct [:image_base64, :solution, :solution_id]

  @numbers ~W(1 2 3 4 5 6)  
  @images ~W(1 2 3 4 5 6)
  @base_path File.cwd!() <> "/assets/static/images/captcha"

  @number_files %{
    "1" => @base_path <> "/1.png",
    "2" => @base_path <> "/2.png",
    "3" => @base_path <> "/3.png",
    "4" => @base_path <> "/4.png",
    "5" => @base_path <> "/5.png",
    "6" => @base_path <> "/6.png"
  }

  @image_files %{
    "1" => @base_path <> "/i1.png",
    "2" => @base_path <> "/i2.png",
    "3" => @base_path <> "/i3.png",
    "4" => @base_path <> "/i4.png",
    "5" => @base_path <> "/i5.png",
    "6" => @base_path <> "/i6.png"
  }

  @background_file @base_path <> "/background.png"

  @geometry %{
    1 => "+0+0",   2 => "+120+0",   3 => "+240+0",
    4 => "+0+120", 5 => "+120+120", 6 => "+240+120",
    7 => "+0+240", 8 => "+120+240", 9 => "+240+240"
  }

  @distortion_1 [
    ~W"-implode .1",
    ~W"-implode -.1"
  ]

  @distortion_2 [
    ~W"-swirl 10",
    ~W"-swirl -10",
    ~W"-swirl 20",
    ~W"-swirl -20"
  ]

  @distortion_3 [
    ~W"-wave 5x180",
    ~W"-wave 5x126",
    ~W"-wave 10x180",
    ~W"-wave 10x126"
  ]

  def create do
    solution =
      Enum.zip(@numbers, Enum.shuffle(@images))
      |> Map.new()

    # 3x3 render grid
    grid = Enum.shuffle(@numbers ++ [nil, nil, nil])

    # Base arguments
    args = [
      "-page", "360x360",
      @background_file
    ]

    # Individual grid files
    files =
      grid
      |> Enum.with_index()
      |> Enum.flat_map(fn {num, index} ->
        if num do
          [
            "(", @image_files[solution[num]], ")", "-geometry", @geometry[index + 1], "-composite",
            "(", @number_files[num], ")", "-geometry", @geometry[index + 1], "-composite"
          ]
        else
          []
        end
      end)

    # Distortions for more unpredictability
    distortions =
      [
        Enum.random(@distortion_1),
        Enum.random(@distortion_2),
        Enum.random(@distortion_3)
      ]
      |> Enum.shuffle()
      |> List.flatten()

    jpeg = ~W"-quality 8 jpeg:-"

    {image, 0} = System.cmd("convert", args ++ files ++ distortions ++ jpeg)
    image = image |> Base.encode64()

    # Store solution in redis to prevent reuse
    # Solutions are valid for 10 minutes
    solution_id =
      :crypto.strong_rand_bytes(12)
      |> Base.encode16(case: :lower)
    solution_id = "cp_" <> solution_id

    {:ok, _ok} = Redix.command(:redix, ["SET", solution_id, Jason.encode!(solution)])
    {:ok, _ok} = Redix.command(:redix, ["EXPIRE", solution_id, 600])

    %Philomena.Captcha{
      image_base64: image,
      solution: solution,
      solution_id: solution_id
    }
  end

  def valid_solution?(<<"cp_", _rest::binary>> = solution_id, solution) when is_map(solution) do
    # Delete key immediately. This may race, but should
    # have minimal impact if the race succeeds.
    with {:ok, sol} <- Redix.command(:redix, ["GET", solution_id]),
         {:ok, _del} <- Redix.command(:redix, ["DEL", solution_id]),
         {:ok, sol} <- Jason.decode(to_string(sol))
    do
      Map.equal?(solution, sol)
    else
      _ ->
        false
    end
  end

  def valid_solution?(_solution_id, _solution),
    do: false

  def valid_solution?(%{"captcha" => %{"id" => id, "sln" => solution}}) do
    valid_solution?(id, solution)
  end

  def valid_solution?(_params),
    do: false
end
