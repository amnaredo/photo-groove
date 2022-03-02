module PhotoGrooveTests exposing (..)

import Expect exposing (Expectation)
import Fuzz exposing (Fuzzer, int, list, string)
import Test exposing (..)
import PhotoGroove exposing (Model, Msg(..), Photo, Status(..),
    initialModel, update, urlPrefix, view)
import Json.Decode as Decode exposing (decodeValue)
import Json.Encode as Encode
import Html.Attributes as Attr exposing (src)
import Test.Html.Query as Query
import Test.Html.Selector exposing (text, tag, attribute)


thumbnailsWork : Test
thumbnailsWork =
    fuzz (Fuzz.intRange 1 5) "URLs render as thumbnails" <|
        \urlCount ->
            let
                urls : List String
                urls =
                    List.range 1 urlCount
                        |> List.map (\num -> String.fromInt num ++ ".png")
                
                thumbnailChecks : List (Query.Single msg -> Expectation)
                thumbnailChecks =
                    List.map thumbnailRendered urls
            in
            { initialModel | status = Loaded (List.map photoFromUrl urls ) "" }
                |> view
                |> Query.fromHtml
                |> Expect.all thumbnailChecks


photoFromUrl : String -> Photo
photoFromUrl url =
    { url = url, size = 0, title = "" }

thumbnailRendered : String -> Query.Single msg -> Expectation
thumbnailRendered url query =
    query
        |> Query.findAll [ tag "img", attribute (Attr.src (urlPrefix ++ url)) ]
        |> Query.count (Expect.atLeast 1)


noPhotosNoThumbnails : Test
noPhotosNoThumbnails =
    test "No thumbnails render when there are no photos to render" <|
        \_ ->
            initialModel
                |> PhotoGroove.view
                |> Query.fromHtml
                |> Query.findAll [ tag "img" ]
                |> Query.count (Expect.equal 0)


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