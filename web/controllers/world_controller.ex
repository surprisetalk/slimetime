defmodule SlimeTime.WorldController do
  use SlimeTime.Web, :controller

  def map(conn, _params) do
    {:ok, r} = Redix.start_link()
    world = Redix.command!(r, ~w(GETRANGE world 0 -1))
    text conn, world
  end

  # TODO: should location be long/lat?
  def shoot(conn, %{"col" => col, "loc" => loc}) when is_integer( loc ) do

      {:ok, r} = Redix.start_link()
      loc_ = "#" ++ to_string loc
      col_ = case col do
               "red"   -> 1
               "green" -> 2
               "blue"  -> 3
               _       -> 0
             end
      Redix.command!(r, ~w(BITFIELD world SET u2 ) ++ [ loc_, col_ ])
      SlimeTime.Endpoint.broadcast "lobby", "shout", %{"col" => col, "loc" => loc}
      conn |> put_status(200) |> text("")

  end

  def shoot(conn, _other) do
    conn |> put_status(400) |> render(SlimeTime.ErrorView,"400.html")
  end

end
