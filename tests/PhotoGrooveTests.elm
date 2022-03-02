module PhotoGrooveTests exposing (..)

import Expect exposing (Expectation)
import Fuzz exposing (Fuzzer, int, list, string)
import Test exposing (..)
import PhotoGroove exposing (Model, Msg(..), Photo, initialModel, update)
import Json.Decode as Decode exposing (decodeValue)
import Json.Encode as Encode


sliders : Test
sliders =
    describe "Slider sets the desired field in the Model"
    [ testSlider "SlidHue" SlidHue .hue
    , testSlider "SlidRipple" SlidRipple .ripple
    , testSlider "SlidNoise" SlidNoise .noise
    ]

testSlider : String -> (Int -> Msg) -> (Model -> Int) -> Test
testSlider description toMsg amountFromModel =
    fuzz int description <|
        \amount ->
            initialModel
                |> update (toMsg amount)
                |> Tuple.first
                |> amountFromModel
                |> Expect.equal amount

-- slidHueSetsHue : Test
-- slidHueSetsHue =
--     fuzz int "SlidHue sets the hue" <|
--         \amount ->
--             initialModel
--                 |> update (SlidHue amount)
--                 |> Tuple.first
--                 |> .hue
--                 |> Expect.equal amount

decoderTest : Test
decoderTest =
    fuzz2 string int "title defaults to (untittled)" <|
        \url size ->
            [ ( "url", Encode.string url )
            , ( "size", Encode.int size)
            ]
                |> Encode.object
                |> decodeValue PhotoGroove.photoDecoder
                |> Result.map .title
                |> Expect.equal (Ok "(untitled)")

-- decoderTest : Test
-- decoderTest =
--     test "title defaults to (untittled)" <|
--         \_ ->
--             [ ( "url", Encode.string "fruits.com" )
--             , ( "size", Encode.int 5)
--             ]
--                 |> Encode.object
--                 |> decodeValue PhotoGroove.photoDecoder
--                 |> Result.map .title
--                 |> Expect.equal (Ok "(untitled)")
        


-- suite : Test
-- suite =
--     test "one plus one equals two" (\_ -> Expect.equal 2 (1 + 1))
