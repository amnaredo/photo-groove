module Main exposing (main)

import Browser exposing (Document)
import Browser.Navigation as Nav
import Url exposing (Url)
import Html exposing (Html, a, footer, h1, li, nav, text, ul)
import Html.Attributes exposing (classList, href)
import Html.Lazy exposing (lazy)
import Url.Parser as Parser exposing ((</>), Parser, s, string)
import PhotoFolders as Folders
import PhotoGallery as Gallery

type alias Model =
    { page : Page, key : Nav.Key }

type Page
    = Gallery Gallery.Model
    | Folders Folders.Model
    | NotFound

type Route
    = Gallery
    | Folders
    | SelectedPhoto String

view : Model -> Document Msg
view model =
    let
        content = 
            text "This isn't even my final form!"
    in
    { title = "Photo Groove, SPA Style" 
    , body = 
        [ lazy viewHeader model.page
        , content
        , viewFooter
        ]
    }

viewHeader : Page -> Html Msg
viewHeader page =
    let
        logo =
            h1 [] [ text "Photo Groove" ]
        
        links =
            ul []
                [ navLink Folders { url = "/", caption = "Folders" }
                , navLink Gallery { url = "/gallery", caption = "Gallery" }
                ]
        
        navLink : Route -> { url : String, caption : String } -> Html Msg
        navLink route { url, caption } =
            li [ classList [ ( "active", isActive { link = route, page = page } ) ] ]
                [ a [ href url ] [ text caption ] ]
    in
    nav [] [ logo, links ]
    
isActive : { link: Route, page : Page } -> Bool
isActive { link, page } =
    case ( link,            page        ) of
         ---------------------------------------
         ( Gallery,         GalleryPage         ) -> True
         ( Gallery,         _               ) -> False
         ( Folders,         FoldersPage     ) -> True
         ( Folders,         _               ) -> False
         ( SelectedPhoto _, _               ) -> False


viewFooter : Html msg
viewFooter =
    footer [] [ text "One is never alone with a rubber duck. -Douglas Adams" ]

type Msg
    = ClickedLink Browser.UrlRequest
    | ChangedUrl Url

update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        ClickedLink urlRequest ->
            case urlRequest of
                Browser.External href ->
                    ( model, Nav.load href )

                Browser.Internal url ->
                    ( model, Nav.pushUrl model.key (Url.toString url) )

        ChangedUrl url ->
            ( { model | page = urlToPage url }, Cmd.none )

subscriptions : Model -> Sub Msg
subscriptions model =
    Sub.none

init : () -> Url -> Nav.Key -> ( Model, Cmd Msg )
init flags url key =
    ( { page = urlToPage url, key = key }, Cmd.none )

urlToPage : Url -> Page
urlToPage url =
    Parser.parse parser url
        |> Maybe.withDefault NotFound

parser : Parser (Route -> a) a
parser =
    Parser.oneOf
        [ Parser.map Folders Parser.top
        , Parser.map Gallery (s "gallery")
        , Parser.map SelectedPhoto (s "photos" </> Parser.string)
        ]

main : Program () Model Msg
main =
    Browser.application
    { init = init
    , onUrlRequest = ClickedLink
    , onUrlChange = ChangedUrl
    , subscriptions = subscriptions
    , update = update
    , view = view
    }