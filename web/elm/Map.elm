
module Map exposing (..)

-- IMPORTS ---------------------------------------------------------------------

import Json.Decode  as Decode  exposing (..)
import Result.Extra as Result_ exposing (..)

import Html  exposing (Html)
import Color exposing (..)

import Collage exposing ( defaultLine )
import Element

import Window

import Helper exposing (..)

import List.Extra as List_
-- import Maybe.Extra as Maybe_

import Time exposing (..)


-- MODEL -----------------------------------------------------------------------

type alias Point = ( Float, Float )

type alias Persp
  = { loc  : Point
    , zoom : Float
    }

type alias Coord
    = { x : Float
      , y : Float
      }

-- TODO: do coord lists start and end with the same coord?
type alias Border = List Coord

type alias Map = List Border

-- TODO: move this to a team module
type Team = Squid | Toad | Duck


-- TRANSFORMS ------------------------------------------------------------------

geoListToCoord : List Float -> Result String Coord
geoListToCoord lst
    = case lst of
          [ x, y ] -> Ok  <| Coord (degrees x) (degrees y)
          _        -> Err <| "could not parse list " ++ toString lst ++ " into tuple"


-- DECODER ---------------------------------------------------------------------

decode : Value -> Result String Map
decode = decodeValue cartographyDecoder

cartographyDecoder : Decoder Map
cartographyDecoder
    = Decode.field "features"
    <| Decode.map List.concat
    <| Decode.list featureDecoder

featureDecoder : Decoder Map
featureDecoder
    = Decode.field "geometry"
    <| Decode.andThen coordinatesDecoder
    <| Decode.field "type" Decode.string


coordinatesDecoder : String -> Decoder Map
coordinatesDecoder shapeType
    = Decode.field "coordinates"
    <| case shapeType of
           "Polygon"      -> coordinatesDecoder_ |> Decode.map List.singleton
           "MultiPolygon" -> coordinatesDecoder_ |> Decode.list
           _              -> Decode.fail <| "bad shape: " ++ shapeType

coordinatesDecoder_ : Decoder Border
coordinatesDecoder_
    = Decode.map (List.concat >> Result_.combine >> Result.withDefault [])
    <| Decode.list
    <| Decode.list
    <| Decode.map geoListToCoord
    <| Decode.list Decode.float


-- DECODER ---------------------------------------------------------------------

-- -- TODO: use html touch/scroll interactions to take over zoom?
view : Team -> Time -> Window.Size -> Persp -> Map -> Html msg
view team time { width, height } { loc, zoom } map
  = let t : Float
        t = inHours time %% 24
        w : Float
        w = toFloat width
        h : Float
        h = toFloat height
        m : Float
        m = max w h
        coordToPoint : Coord -> Point
        coordToPoint {x,y} = (x,y)
        mapProjection : Point -> Point -> Maybe Point
        mapProjection (x_,y_) (x,y)
          = if   0 <= (sin y_ * sin y) + (cos y_ * cos y * cos (x-x_))
            then Just (                         (           (cos y) * (sin (x-x_)))  * m * zoom
                      , (((cos y_) * (sin y)) - ((sin y_) * (cos y) * (cos (x-x_)))) * m * zoom
                      )
            else Nothing
        geoToScreen_ : Float -> Float -> Float -> Float
        geoToScreen_ rng geo_ loc_ = (((geo_ - loc_) %% (floor (rng * 2))) - rng) / rng * m / 2 * zoom
        geoToScreen : Coord -> Coord
        geoToScreen {x,y}
          = { x = geoToScreen_ 180 x <| Tuple.first  loc
            , y = geoToScreen_  90 y <| Tuple.second loc }
        formMap : Collage.Form
        formMap = map
                |> List.map formBorder
                |> Collage.group
        snipAtJumps : List Point -> List (List Point)
        snipAtJumps l
          = List_.zip l (cycle 1 l)
          |> fl List.foldr [[]]
            (\((x,y),(x_,y_)) l_ ->
               -- BUG: the axes are getting snipped
               if   x * x_ > 0
               &&   y * y_ > 0
               then mapFirst ((::)  (x,y) ) l_
               else          ((::) [(x,y)]) l_)
        formBorder : Border -> Collage.Form
        formBorder = List.map coordToPoint
                   >> List.map (mapProjection loc)
                   >> mResolveList
                   -- >> snipAtJumps
                   -- >> List.map Collage.path
                   -- >> List.map (Collage.traced borderStyle)
                   >> Collage.path
                   >> Collage.traced borderStyle
        -- TODO: maybe change the color depending on how much time is left in the game?
        hue : Float
        hue = case team of
                Squid -> degrees 200
                Toad  -> degrees   0
                Duck  -> degrees 140
        formBackground : Collage.Form
        formBackground = Collage.rect w h
                       |> Collage.filled (Color.hsl hue
                                         (Tuple.second loc                    |> (*) 2 |> cos |> fl (/) 15 |> (+) 0.40)
                                         (Tuple.first  loc |> (+) (t / 12 * pi) |> (+) pi |> cos |> fl (/) 10 |> (+) 0.20))
        borderStyle : Collage.LineStyle
        borderStyle = { defaultLine
                        | color = lightCharcoal
                        , width = 1
                      }
    in  [ formBackground, formMap ]
        |> Collage.collage width height
        |> Element.toHtml

