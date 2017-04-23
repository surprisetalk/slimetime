
port module SlimeTime exposing (..)

-- IMPORTS ---------------------------------------------------------------------

import Map exposing (..)

import Result.Extra as Result_

import Json.Decode as JD exposing (..)
import Json.Encode as JE exposing (..)
import Html exposing (..)
import Time exposing (..)
import Task
import Mouse
import Window
import Keyboard

import Helper exposing (..)

import Animation exposing (..)
import AnimationFrame exposing (..)

import Phoenix.Socket
import Phoenix.Channel
import Phoenix.Push


-- PORTS -----------------------------------------------------------------------

port cartography : (JE.Value -> msg) -> Sub msg


-- MAIN ------------------------------------------------------------------------

main : Program Never Model Msg
main =
    program
        { init          = init
        , view          = view
        , update        = update
        , subscriptions = subscriptions
        }


-- MODEL -----------------------------------------------------------------------

-- TODO: we may need to move a few of these values into the animations. we can fetch values with `getTo`
type alias Model
  = { map    : Result String Map
    , screen : Window.Size
    , persp  : Persp
    , time   : Time
    , team   : Team
    , phx    : Phoenix.Socket.Socket Msg
    -- user
    }

type alias Point = ( Float, Float )

type alias Persp
  = { loc  : ( Animation, Animation )
    , zoom : Animation
    }


-- INIT ------------------------------------------------------------------------

init : ( Model, Cmd Msg )
init
  = { map    = Err "map not defined"
    , screen = { width = 0, height = 0 }
    , persp  = { loc = ( anim, anim ), zoom = anim }
    , team   = Toad
    , time   = 0
    , phx    = Phoenix.Socket.init "ws://localhost:4000/socket/websocket"
               |> Phoenix.Socket.withDebug
               |> Phoenix.Socket.on   "shout" "lobby" MissileShow
    } ! [ Task.perform ScreenResize Window.size
        , Task.perform TimeUpdate      Time.now ]

anim : Animation
anim = animation 0 |> duration (150*ms)


-- TRANSFORMS ------------------------------------------------------------------

changeTeam : Team -> Model -> Model
changeTeam team model
  = let team_ : Team
        team_ = case team of
                  Squid -> Toad
                  Toad  -> Duck
                  Duck  -> Squid
    in  { model | team = team_ }

mapTo : Time -> (Float -> Float) -> Animation -> Animation
mapTo t f a = getTo a |> f |> fl (retarget t) a

getPerspZoom : Model -> Float
getPerspZoom = .persp >> .zoom >> getTo

mapPerspZoom : Time -> (Float -> Float) -> Model -> Model
mapPerspZoom t f = mapPersp (\p -> { p | zoom = mapTo t f p.zoom })
    
mapPerspLoc : Time -> (Point -> Point) -> Model -> Model
mapPerspLoc t f = mapPersp (\p -> { p | loc = p.loc |> mapBoth getTo |> f |> \(x,y) -> (retarget t x (Tuple.first p.loc), retarget t y (Tuple.second p.loc)) })

mapPersp : (Persp -> Persp) -> Model -> Model
mapPersp f model = setPersp (f model.persp) model

setPersp : Persp -> Model -> Model
setPersp persp_ model = { model | persp = persp_ }


-- MESSAGES --------------------------------------------------------------------

type Msg
  = NoOp
  | MapUpdate (Result String Map)
  | KeyMsg Keyboard.KeyCode
  | ScreenResize Window.Size
  | TimeUpdate Time
  | PhoenixMsg (Phoenix.Socket.Msg Msg)
  | MissileShow JE.Value
  | MissileSend Mouse.Position


-- UPDATE ----------------------------------------------------------------------

update : Msg -> Model -> ( Model, Cmd Msg )
update msg model
  = let keyPerspLoc : ((Float -> Float) -> Point -> Point) -> (Float -> Float -> Float) -> Model -> Model
        keyPerspLoc fp fn = mapPerspLoc model.time <| fp <| fn <| pi / 32 / getPerspZoom model
        -- TODO: use shift (16) for larger jumps
        keyPersp : Keyboard.KeyCode -> Model -> Model
        keyPersp code
          = case code of
              37 -> keyPerspLoc Tuple.mapFirst  <| fl (-)     -- left
              38 -> keyPerspLoc Tuple.mapSecond <|    (+)     -- up
              39 -> keyPerspLoc Tuple.mapFirst  <|    (+)     -- right
              40 -> keyPerspLoc Tuple.mapSecond <| fl (-)     -- down
              74 -> mapPerspZoom     model.time <| fl (-) 0.1 -- j
              75 -> mapPerspZoom     model.time <|    (+) 0.1 -- k
              84 -> changeTeam       model.team
              _  -> identity
    in  case msg of
          NoOp              ->   model                   ! []
          KeyMsg       code -> ( model |> keyPersp code ) ! []
          MapUpdate    map_ -> { model | map    = map_ } ! []
          TimeUpdate     t_ -> { model | time   =   t_ } ! []
          ScreenResize size -> { model | screen = size } ! []
          MissileShow   val ->   model                   ! []
          MissileSend {x,y} ->   model                   ! []
          PhoenixMsg   msg_ -> let ( phxSocket, phxCmd ) = Phoenix.Socket.update msg_ model.phx
                              in  ( { model | phx = phxSocket }
                                  , Cmd.map PhoenixMsg phxCmd
                                  )


-- SUBSCRIPTIONS ---------------------------------------------------------------

-- TODO: location
subscriptions : Model -> Sub Msg
subscriptions model
  = Sub.batch
        [ Mouse.clicks MissileSend
        , Keyboard.downs KeyMsg
        , cartography (Map.decode >> MapUpdate)
        , Window.resizes ScreenResize
        , AnimationFrame.times TimeUpdate
        , Phoenix.Socket.listen model.phx PhoenixMsg
        -- , Time.every (Time.second    ) (\_ -> KeyMsg 38)
        -- , Time.every (Time.second / 2) (\_ -> KeyMsg 37)
        ]


-- VIEW ------------------------------------------------------------------------

view : Model -> Html Msg
view { map, team, time, screen, persp }
  = Result_.unwrap
    (text "error: could not decode map")
    (Map.view team time screen { loc = mapBoth (animate time) persp.loc, zoom = animate time persp.zoom })
    map
    
