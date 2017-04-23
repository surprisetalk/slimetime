
module Helper exposing (..)

import Maybe.Extra as Maybe_

import Time exposing ( Time, millisecond )

fl : (a -> b -> c) -> b -> a -> c
fl = flip     

(+:) : List x -> x -> List x
(+:) xs x = xs ++ [ x ]

(%%) : Float -> Int -> Float
(%%) x y = floor x % y
         |> toFloat
         |> (+) (x - (toFloat (floor x)))

mapFirst : (x -> x) -> List x -> List x
mapFirst f xs
  = case xs of
      []       -> []
      x :: xs_ -> f x :: xs_

mapBoth : (a -> b) -> (a,a) -> (b,b)
mapBoth f (x,y) = ( f x , f y )

cycle : Int -> List x -> List x
cycle n xs = List.drop n xs ++ List.take n xs

mResolveList : List (Maybe x) -> List x
mResolveList = fl List.foldr [] <| (++) << Maybe_.unwrap [] List.singleton
               
toDegrees : Float -> Float 
toDegrees = (*) pi >> fl (/) 180

fromDegrees : Float -> Float
fromDegrees = degrees 

ms : Time
ms = millisecond
