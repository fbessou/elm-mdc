module Material.Ripple exposing
    ( accent
    , bounded
    , defaultModel
    , Model
    , Msg
    , primary
    , Property
    , react
    , unbounded
    , update
    , view
    )

{-|
The Ripple component adds a material "ink ripple" interaction effect to
HTML elements.

The ripple comes in `bounded` and `unbounded` variants. The first works well
for surfaces, the other works well for icons.

The view functions `unbounded` and `bounded` return a record with fields

- `interactionHandler` that has to be added to the HTML element that should be
  interacted with,
- `properties` that applies the ripple effect to the HTML element. This is
  usually the same as the one `interactionHandler` is applied to, and
- `style` which is a HTML `<style>` element which has to be added to the DOM.
  It is recommended to make this a child of the element that is interacted
  with.


# Resources
- [Material Design guidelines: Choreography](https://material.io/guidelines/motion/choreography.html#choreography-radial-reaction)
- [Demo](https://aforemny.github.io/elm-mdc/#ripple)


# Example

## Bounded Ripple effect

```elm
let
    { interactionHandler
    , properties
    , style
    } =
        Ripple.bounded Mdc [0] model.mdc
in
Options.styled Html.div
    [ interactionHandler
    , properties
    ]
    [ text "Interact with me!"
    , style
    ]
```


## Unbounded Ripple effect

```elm
let
    { interactionHandler
    , properties
    , style
    } =
        Ripple.unbounded Mdc [0] model.mdc
in
Icon.view
    [ interactionHandler
    , properties
    ]
    "favorite"
```


# Usage
@docs Property
@docs unbounded
@docs bounded
@docs primary
@docs accent


# Internal
@docs Model
@docs defaultModel
@docs Msg
@docs update
@docs view
@docs react
-}

import DOM
import Html.Attributes as Html
import Html exposing (..)
import Json.Decode as Json exposing (Decoder, field, at)
import Material.Component as Component exposing (Indexed)
import Material.Helpers as Helpers
import Material.Internal.Options as Internal
import Material.Internal.Ripple exposing (Msg(..), Geometry, defaultGeometry)
import Material.Msg exposing (Index)
import Material.Options as Options exposing (styled, cs, css, when)
import Platform.Cmd exposing (Cmd, none)


{-| Ripple model.

Internal use only.
-}
type alias Model =
    { focus : Bool
    , active : Bool
    , animating : Bool
    , deactivation : Bool
    , geometry : Geometry
    , animation : Int
    }


{-| Ripple default model.

Internal use only.
-}
defaultModel : Model
defaultModel =
    { focus = False
    , active = False
    , animating = False
    , deactivation = False
    , geometry = defaultGeometry
    , animation = 0
    }


{-| Ripple message.

Internal use only.
-}
type alias Msg
    = Material.Internal.Ripple.Msg


{-| Ripple update function.

Internal use only.
-}
update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of

        Focus ->
            ( { model | focus = True }, Cmd.none )

        Blur ->
            ( { model | focus = False }, Cmd.none)

        Activate event active_ geometry ->
            let
                isVisible =
                    model.active || model.animating
            in
            if not isVisible then
                let
                    active =
                        active_
                        |> Maybe.withDefault model.active

                    animation =
                        model.animation + 1
                in
                ( { model
                      | active = active
                      , animating = True
                      , geometry = geometry
                      , deactivation = False
                      , animation = animation
                  }
                ,
                  Helpers.delay 300 (AnimationEnd event animation)
                )
            else
                ( model, Cmd.none )

        Deactivate event ->
            let
                sameEvent =
                    case model.geometry.event.type_ of
                        "keydown" ->
                            event == "keyup"
                        "mousedown" ->
                            event == "mouseup"
                        "pointerdown" ->
                            event == "pointerup"
                        "touchstart" ->
                            event == "touchend"
                        _ -> False
            in
            if sameEvent then
                ( { model | active = False }, Cmd.none )
            else
                ( model, Cmd.none )

        AnimationEnd event animation ->
            if (model.geometry.event.type_ == event) && (animation == model.animation) then
                ( { model | animating = False }, Cmd.none )
            else
                ( model, Cmd.none )


{-| Bounded view function.
-}
bounded
    : (Material.Msg.Msg m -> m)
    -> Index
    -> Store s
    -> List (Property m)
    -> { interactionHandler : Options.Property c m
       , properties : Options.Property c m
       , style : Html m
       }
bounded =
    Component.render get (view False) Material.Msg.RippleMsg


{-| Unbounded view function.
-}
unbounded
    : (Material.Msg.Msg m -> m)
    -> Index
    -> Store s
    -> List (Property m)
    -> { interactionHandler : Options.Property c m
       , properties : Options.Property c m
       , style : Html m
       }
unbounded =
    Component.render get (view True) Material.Msg.RippleMsg


type alias Config =
    { color : Maybe String
    }


defaultConfig : Config
defaultConfig =
    { color = Nothing
    }


{-| Set ripple effect to the primary color.
-}
primary : Property m
primary =
    Internal.option (\ config -> { config | color = Just "primary" })


{-| Set ripple effect to the accent color.
-}
accent : Property m
accent =
    Internal.option (\ config -> { config | color = Just "accent" })


{-| Ripple property.
-}
type alias Property m =
    Options.Property Config m


{-| Ripple view function.

Internal use only. Use `bounded` or `unbounded` instead.
-}
view : Bool
    -> (Msg -> m)
    -> Model
    -> List (Property m)
    -> { interactionHandler : Options.Property c m
       , properties : Options.Property c m
       , style : Html m
       }
view isUnbounded lift model options =
    let
        { config } =
            Internal.collect defaultConfig options

        geometry =
            model.geometry

        surfaceWidth =
            toString geometry.frame.width ++ "px"

        surfaceHeight =
            toString geometry.frame.height ++ "px"

        fgSize =
            toString initialSize ++ "px"

        surfaceDiameter =
            sqrt ((geometry.frame.width^2) + (geometry.frame.height^2))

        maxRadius =
            if isUnbounded then
              maxDimension
            else
              surfaceDiameter + 10

        fgScale =
            toString (maxRadius / initialSize)

        maxDimension =
            Basics.max geometry.frame.width geometry.frame.height

        initialSize =
            maxDimension * 0.6

        startPoint =
            if wasActivatedByPointer && not isUnbounded then
                { x = geometry.event.pageX - (initialSize / 2)
                , y = geometry.event.pageY - (initialSize / 2)
                }
            else
                { x = toFloat (round ((geometry.frame.width - initialSize) / 2))
                , y = toFloat (round ((geometry.frame.height - initialSize) / 2))
                }

        endPoint =
            { x = (geometry.frame.width - initialSize) / 2
            , y = (geometry.frame.height - initialSize) / 2
            }

        translateStart =
            toString startPoint.x ++ "px, " ++ toString startPoint.y ++ "px"

        translateEnd =
            toString endPoint.x ++ "px, " ++ toString endPoint.y ++ "px"

        wasActivatedByPointer =
            List.member geometry.event.type_
            [ "mousedown"
            , "touchstart"
            , "pointerdown"
            ]

        top =
            toString startPoint.y ++ "px"

        left =
            toString startPoint.x ++ "px"

        summary =
          Internal.collect ()
          ( List.concat
            [
              [ Internal.variable "--mdc-ripple-fg-size" fgSize
              , Internal.variable "--mdc-ripple-fg-scale" fgScale
              ]
            , if isUnbounded then
                  [ Internal.variable "--mdc-ripple-top" top
                  , Internal.variable "--mdc-ripple-left" left
                  ]
              else
                  [ Internal.variable "--mdc-ripple-fg-translate-start" translateStart
                  , Internal.variable "--mdc-ripple-fg-translate-end" translateEnd
                  ]
            ]
          )

        (selector, styleNode) =
            Internal.cssVariables summary

        focusOn event =
            Options.on event (Json.succeed (lift Focus))

        blurOn event =
            Options.on event (Json.succeed (lift Blur))

        activateOn event =
            Options.on event <|
            Json.map (lift << Activate event (Just True)) (decodeGeometry event)

        deactivateOn event =
            Options.on event (Json.succeed (lift (Deactivate event)))

        isVisible =
            model.active || model.animating

        interactionHandler =
            Options.many
            [ focusOn "focus"
            , blurOn "blur"
            , Options.many <|
              List.map activateOn
              [ "keydown"
              , "mousedown"
              , "pointerdown"
              , "touchstart"
              ]
            , Options.many <|
              List.map deactivateOn
              [ "keyup"
              , "mouseup"
              , "pointerup"
              , "touchend"
              ]
            ]

        properties =
            Options.many
            [
              cs "mdc-ripple-upgraded"
            , cs "mdc-ripple-surface"

            , when (config.color == Just "primary") <|
              cs "mdc-ripple-surface--primary"

            , when (config.color == Just "accent") <|
              cs "mdc-ripple-surface--accent"

            , when isUnbounded << Options.many <|
              [ cs "mdc-ripple-upgraded--unbounded"
              , Options.data "data-mdc-ripple-is-unbounded" ""
              ]

            , when isVisible << Options.many <|
              [ cs "mdc-ripple-upgraded--background-active-fill"
              , cs "mdc-ripple-upgraded--foreground-activation"
              ]

            , when model.deactivation <|
              cs "mdc-ripple-upgraded--foreground-deactivation"

            , when model.focus <|
              cs "mdc-ripple-upgraded--background-focused"

            , -- CSS variable hack selector:
              when isVisible (cs selector)
            ]

        style =
            if isVisible then
                styleNode
            else
                Html.node "style"
                [ Html.type_ "text/css"
                ]
                []
    in
    { interactionHandler = interactionHandler
    , properties = properties
    , style = style
    }


type alias Store s =
    { s | ripple : Indexed Model
    }


( get, set ) =
    Component.indexed .ripple (\x y -> { y | ripple = x }) defaultModel


{-| Ripple react.

Internal use only.
-}
react : (Material.Msg.Msg m -> m) -> Msg -> Index -> Store s -> ( Maybe (Store s), Cmd m )
react =
    Component.react get set Material.Msg.RippleMsg (Component.generalise update)


decodeGeometry : String -> Decoder Geometry
decodeGeometry type_ =
    let
        windowPageOffset =
          Json.map2 (\ x y -> { x = x, y = y })
            (Json.at ["pageXOffset"] Json.float)
            (Json.at ["pageYOffset"] Json.float)

        isSurfaceDisabled =
          Json.oneOf
          [ Json.map (always True) (Json.at [ "disabled" ] Json.string)
          , Json.succeed False
          ]

        boundingClientRect pageOffset =
          DOM.boundingClientRect
          |> Json.map (\ { top, left, width, height } ->
               { top = top - pageOffset.y
               , left = left - pageOffset.x
               , width = width
               , height = height
               }
             )

        normalizeCoords pageOffset clientRect { pageX, pageY } =
          let
            documentX =
              pageOffset.x + clientRect.left

            documentY =
              pageOffset.y + clientRect.top

            x =
              pageX - documentX

            y =
              pageY - documentY
          in
          { x = x, y = y }

        changedTouches =
          Json.at ["changedTouches"] (Json.list changedTouch)

        changedTouch =
          Json.map2 (\ pageX pageY -> { pageX = pageX, pageY = pageY })
            (Json.at ["pageX"] Json.float)
            (Json.at ["pageY"] Json.float)

        currentTarget =
          Json.at ["currentTarget"]

        view =
          Json.at ["view"]
    in
    Json.map4
      (\ coords pageOffset clientRect isSurfaceDisabled ->
          let
            { x, y } =
              normalizeCoords pageOffset clientRect coords
            event =
              { type_ = type_
              , pageX = x
              , pageY = y
              }
          in
          { event = event
          , isSurfaceDisabled = isSurfaceDisabled
          , frame = clientRect
          }
      )
      ( if type_ == "touchstart" then
            changedTouches
            |> Json.map List.head
            |> Json.map (Maybe.withDefault { pageX = 0, pageY = 0 })
        else
            Json.map2 (\ pageX pageY -> { pageX = pageX, pageY = pageY })
              (Json.at ["pageX"] Json.float)
              (Json.at ["pageY"] Json.float)
      )
      (view windowPageOffset)
      ( view windowPageOffset
        |> Json.andThen (currentTarget << boundingClientRect)
      )
      (currentTarget isSurfaceDisabled)
