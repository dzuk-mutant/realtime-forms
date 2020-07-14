module Form.Updatable exposing ( enableUpdates
                               , disableUpdates
                               , toggleUpdates
                               )


{-|
-}
type alias Updatable r =
    { r | updatesEnabled : Bool
    }


{-| Enables updates in the field.
-}
enableUpdates : Updatable r -> Updatable r
enableUpdates v = { v | updatesEnabled = True }

{-| Disables updates in the field.
-}
disableUpdates : Updatable r -> Updatable r
disableUpdates v = { v | updatesEnabled = False }

{-| Toggles updates in the field.
-}
toggleUpdates : Updatable r -> Updatable r
toggleUpdates v = { v | updatesEnabled = not v.updatesEnabled }
