module PhotoFolders exposing (Model, Msg, init, update, view)

import Browser
import Html exposing (..)
import Html.Attributes exposing (class, src)
import Html.Events exposing (onClick)
import Http
import Json.Decode as Decode exposing (Decoder, int, list, string)
import Json.Decode.Pipeline exposing (required)
import Dict exposing (Dict)


type alias Model = 
    { selectedPhotoUrl : Maybe String
    , photos : Dict String Photo
    , root : Folder
    }

type Folder =
    Folder -- single variant has the same name as the type
        { name : String
        , photoUrls : List String
        , subfolders : List Folder
        , expanded : Bool
        }

initialModel : Model
initialModel =
    { selectedPhotoUrl = Nothing
    , photos = Dict.empty
    , root = Folder { name  = "Loading...", expanded = True, photoUrls = [], subfolders = [] }
    }

init : Maybe String -> ( Model, Cmd Msg )
init selectedFilename =
    ( { initialModel | selectedPhotoUrl = selectedFilename }
    , Http.get
        { url = "http://elm-in-action.com/folders/list"
        , expect = Http.expectJson GotInitialModel modelDecoder
        }
    )

modelDecoder : Decoder Model
modelDecoder =
    Decode.map2 -- if both decoders succeed, run the callback to get the final value
        (\photos root ->
            { photos = photos, root = root, selectedPhotoUrl = Nothing }    
        )
        modelPhotosDecoder
        folderDecoder


type Msg 
    = ClickedPhoto String
    | GotInitialModel (Result Http.Error Model)
    | ClickedFolder FolderPath

update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        ClickedFolder path ->
            ( { model | root = toggleExpanded path model.root }, Cmd.none )

        ClickedPhoto url ->
            ( { model | selectedPhotoUrl = Just url }, Cmd.none )
        
        GotInitialModel (Ok newModel) ->
            ( newModel, Cmd.none )

        GotInitialModel (Err _) ->
            ( model, Cmd.none )

view : Model -> Html Msg
view model =
    let
        photoByUrl : String -> Maybe Photo
        photoByUrl url =
            Dict.get url model.photos
        
        selectedPhoto : Html Msg
        selectedPhoto =
            case Maybe.andThen photoByUrl model.selectedPhotoUrl of -- like Maybe.map, except it can change outcome to Nothing
                Just photo ->
                    viewSelectedPhoto photo
                
                Nothing ->
                    text ""

        -- previous version, not using Maybe.andThen
        -- selectedPhoto : Html Msg
        -- selectedPhoto =
        --     case model.selectedPhotoUrl of
        --         Just url ->
        --             case Dict.get url model.photos of
        --                 Just photo ->
        --                     viewSelectedPhoto photo
                        
        --                 Nothing ->
        --                     text ""
                
        --         Nothing ->
        --             text ""

    in
    div [ class "content" ]
        [ div [ class "folders" ]
            [ h1 [] [ text "Folders" ]
            , viewFolder End model.root
            ]
        , div [ class "selected-photo" ] [ selectedPhoto ]
        ]

main : Program () Model Msg
main =
    Browser.element
        { init = init
        , view = view
        , update = update
        , subscriptions = \_ -> Sub.none
        }

type alias Photo =
    { title : String
    , size : Int
    , relatedUrls : List String
    , url : String
    }

viewPhoto : String -> Html Msg
viewPhoto url =
    div [ class "photo", onClick (ClickedPhoto url) ]
        [ text url ]


viewSelectedPhoto : Photo -> Html Msg
viewSelectedPhoto photo =
    div
        [ class "selected-photo" ]
        [ h2 [] [ text photo.title ]
        , img [ src (urlPrefix ++ "photos/" ++ photo.url ++ "/full") ] []
        , span [] [ text "Related" ]
        , div [ class "related-photos" ]
            (List.map viewRelatedPhoto photo.relatedUrls)
        ]
        

viewRelatedPhoto : String -> Html Msg
viewRelatedPhoto url =
    img
        [ class "related-photo"
        , onClick (ClickedPhoto url)
        , src (urlPrefix ++ "photos/" ++ url ++ "/thumb")
        ]
        []

viewFolder : FolderPath -> Folder -> Html Msg
viewFolder path (Folder folder) =
    let
        viewSubfolder : Int -> Folder -> Html Msg
        viewSubfolder index subfolder =
            viewFolder (appendIndex index path) subfolder -- recursive function
        
        folderLabel =
            label [ onClick (ClickedFolder path) ] [ text folder.name ]
    in
    if folder.expanded then
        let
            contents =
                List.append
                    (List.indexedMap viewSubfolder folder.subfolders) -- like map, but callback receives current index as arg
                    (List.map viewPhoto folder.photoUrls)
        in
        div [ class "folder expanded" ]
            [ folderLabel
            , div [ class "contents" ] contents
            ]
    else
        div [ class "folder collapsed" ] [ folderLabel ]


appendIndex : Int -> FolderPath -> FolderPath
appendIndex index path =
    case path of
        End ->
            Subfolder index End
        
        Subfolder subfolderIndex remainingPath ->
            Subfolder subfolderIndex (appendIndex index remainingPath) 

-- viewFolder : FolderPath -> Folder -> Html Msg
-- viewFolder path (Folder folder) = -- destructuring single-variant custom type (instead of case-expression)
--     let
--         subfolders =
--             List.map viewFolder folder.subfolders
--     in
--     div [ class "folder" ]
--         [ label [] [ text folder.name ]
--         , div [ class "subfolders" ] subfolders
--         ]

type FolderPath -- recursive custom type
    = End
    | Subfolder Int FolderPath

toggleExpanded : FolderPath -> Folder -> Folder
toggleExpanded path (Folder folder) =
    case path of
        End ->
            Folder { folder | expanded = not folder.expanded }

        Subfolder targetIndex remainingPath ->
            let
                subfolders : List Folder
                subfolders =
                    List.indexedMap transform folder.subfolders

                transform : Int -> Folder -> Folder
                transform currentIndex currentSubfolder =
                    if currentIndex == targetIndex then
                        toggleExpanded remainingPath currentSubfolder

                    else
                        currentSubfolder
            in
            Folder { folder | subfolders = subfolders }

type alias JsonPhoto =
    { title : String
    , size : Int
    , relatedUrls : List String
    }

jsonPhotoDecoder : Decoder JsonPhoto
jsonPhotoDecoder =
    Decode.succeed JsonPhoto
        |> required "title" string
        |> required "size" int
        |> required "related_photos" (list string)

finishPhoto : ( String, JsonPhoto ) -> ( String, Photo )
finishPhoto ( url, json ) =
    ( url
    , { url = url
      , size = json.size
      , title = json.title
      , relatedUrls = json.relatedUrls
      }
    )

fromPairs : List ( String, JsonPhoto ) -> Dict String Photo
fromPairs pairs =
    pairs
        |> List.map finishPhoto
        |> Dict.fromList

photosDecoder : Decoder (Dict String Photo)
photosDecoder =
-- First decode the photos into key-value
-- pairs; then finish turning them into a Dict of Photo records.
    Decode.keyValuePairs jsonPhotoDecoder
        |> Decode.map fromPairs

folderDecoder : Decoder Folder
folderDecoder = 
    Decode.succeed folderFromJson
        |> required "name" string
        |> required "photos" photosDecoder
        |> required "subfolders" (Decode.lazy (\_ -> list folderDecoder)) -- to break the cyclic definition

folderFromJson : String -> Dict String Photo -> List Folder -> Folder
folderFromJson name photos subfolders =
    Folder
        { name = name
        , expanded = True
        , subfolders = subfolders
        , photoUrls = Dict.keys photos
        }

modelPhotosDecoder : Decoder (Dict String Photo)
modelPhotosDecoder = 
    Decode.succeed modelPhotosFromJson
        |> required "photos" photosDecoder
        |> required "subfolders" (Decode.lazy (\_ -> list modelPhotosDecoder))

modelPhotosFromJson : Dict String Photo -> List (Dict String Photo) -> Dict String Photo
modelPhotosFromJson folderPhotos subfolderPhotos =
    List.foldl Dict.union folderPhotos subfolderPhotos


urlPrefix : String
urlPrefix =
    "http://elm-in-action.com/"