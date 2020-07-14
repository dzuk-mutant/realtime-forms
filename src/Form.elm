module Form exposing ( Form
                     , empty
                     , prefilled

                     , replaceValues

                     , State(..)
                     , changeState
                     , setDone
                     , setSaving

                     , isUpdatable
                     , isFieldUpdatable
                     , isSubmissible
                     , addHttpErr

                     , validate
                     , validateField

                     , FieldSetter
                     , FieldGetter
                     , getField
                     , getFieldVal

                     , updateField
                     , updateFieldWithoutValidation
                     , updateFieldManually
                     , updateFieldManuallyWithoutValidation
                     , showAnyFieldErr

                     , submit
                     )

{-| Setting up, manipulating and handling forms.


# Form
@docs Form



# Creating Forms
@docs empty, prefilled



# Manipulation
@docs replaceValues



# Validation
@docs validate



# Field access
Types and functions for accessing and handling `Field` values within a `Form`.

Basically lenses. I'm so sorry.
@docs FieldSetter, FieldGetter, getField, getFieldVal



# Update functions for input event handlers
Functions for storing user input changes and validating them as they are being inputted.

## Designed for event handlers like onInput
@docs updateField, updateFieldWithoutValidation

## Designed for event handlers like onClick
@docs updateFieldManually, updateFieldManuallyWithoutValidation

## Functions that don't change values, only metadata
Useful for event handlers like onBlur.
@docs showAnyFieldErr


-}



import Form.Field as Field exposing (Field)
import Form.Updatable as Updatable
import Form.Validatable as Validatable exposing (ErrBehavior(..), ErrVisibility(..), Validity(..), isValid, validate)
import Form.Validator exposing (ValidatorSet(..))
import Html exposing (b)
import Http
import Json.Decode exposing (field)


{-| A type that represents your whole form, including it's validation state.

This is almost the same as `Validatable.Validatable`, but with an extra fieldValidation field.
This field is a function for basically triggering validation for all the form's fields
that require validation (as that can't be done automatically).

See `Form.Validatable.Validatable` to understand most of this record structure,
for the things that aren't in Validatable:

- updatesEnabled : Boolean saying explicitly whether or not the user can edit or submit the form right now.\
- state : A custom type (State) describing what stage of the form lifecycle the form is at.
May also dictate whether or not the user can edit or submit.
- httpErr : A temporary fix for now for how to display HTTP errors to the user when a form fails to be submitted.
-}
type alias Form b =
    { value : b
    , validators : ValidatorSet b
    , fieldValidation : b -> b

    , validity : Validity
    , errMsg : String
    , errVisibility : ErrVisibility
    , errBehavior : ErrBehavior

    , updatesEnabled : Bool
    , state : State

    -- TEMP: Currently just getting some sort of HTTP errors out.
    , httpErr : String
    }







{-| Creates a `Form` that is set up in a state which assumes
that the user hasn't filled in this particular form yet (therefore, it is `Unchecked`).

Because there are many possible representations for empty `Field`s out there,
you have to enter in what 'empty' means for the value itself.

A `Form.empty` should always be used with `Field.empty`.

    initModel : Model
    initModel =
        { registerForm = Form.empty registerValidators registerFieldValidation
                                        { username = Field.empty usernameValidators ""
                                        , email = Field.empty emailValidators  ""
                                        , tos = Field.empty tosValidators False
                                        }
        }

-}
empty : ValidatorSet b -> (b -> b) -> b -> Form b
empty valis fieldValis val =
    { value = val
    , validators  = valis
    , fieldValidation = fieldValis

    , validity = Unchecked
    , errMsg = ""
    , errVisibility = HideErr
    , errBehavior = TriggeredValidation

    , updatesEnabled = True
    , state = Unsaved
    , httpErr = ""
    }

{-| Creates a `Form` that is set up in a state which assumes
that the user has filled in this data point before, and therefore assumes it's already`Valid`.

Designed for forms that a user is returning to.

In addition to being `Valid`, the validation behavior is set so that validation errors are set to
show immediately.

The state of this form has been set to FormSaved (assuming that this has been saved to the server before).

    initModel : Model
    initModel =
        { profileForm = Form.prefilled profileValidators profileFieldValidation
                                       { displayName = Field.prefilled displayNameValidators "Dzuk"
                                       , bio = Field.prefilled bioValidators "Big gay orc."
                                       , botAccount = Field.prefilled PassValidation False
                                       , adultAccount = Field.prefilled PassValidation False
                                       }
        }
-}
prefilled : ValidatorSet b -> (b -> b) -> b -> Form b
prefilled valis fieldValis val =
    { value = val
    , validators  = valis
    , fieldValidation = fieldValis

    , validity = Valid
    , errMsg = ""
    , errVisibility = HideErr
    , errBehavior = AlwaysValidation -- prefilled forms should keep the user more clued in to errors.

    , updatesEnabled = True
    , state = Saved
    , httpErr = ""
    }


{-| Take a `Form`, and replaces it's values with the one given. This does not validate the result.

    initialForm = Form.prefilled { displayName = Field.prefilled "Dzuk"
                                   , bio = Field.prefilled "Big gay orc."
                                   , botAccount = Field.prefilled False
                                   , adultAccount = Field.prefilled False
                                   }

    newFormValue = { displayName = Field.prefilled "Someone else"
               , bio = Field.prefilled "Not as cool as Dzuk."
               , botAccount = Field.prefilled False
               , adultAccount = Field.prefilled False
               }

    replaceValues initialForm newFormValue
-}
replaceValues : Form b -> b -> Form b
replaceValues form val =
    case form.updatesEnabled of
        False -> form
        True -> { form | value = val }








{-| A type representing the different states a form can be in.

- FormUnsaved : The form (in it's current state at least) has not been saved.
- FormSaving : The form is being sent to the server.
User access should be disabled.
- FormSaved : The form (in it's current state) has been saved and can be entered
by the user again.
- FormDone : The form has been complete and sent, and the user should not enter
anything more and the UI should move onto something else. User access should be disabled.


It doesn't encapsulate one lifecycle, but two potentially different ones.

#### One-time form
`FormUnsaved` -> `FormSaving` -> `FormDone` (at which point the user cannot edit this anymore and the UI moves to something else)

#### Returning form
`FormUnsaved` -> `FormSaving` -> `FormSaved` (at which point the user can edit and save the form again)

-}
type State = Unsaved | Saving | Saved | Done



{-| Changes the form state to onoe of your choosing.
-}
changeState : State -> Form b -> Form b
changeState newState form = { form | state = newState }

-- TEMP
{-| Convenience function that sets the form to Saving
and erases the last HTTP error message (if any).
-}
setSaving : Form b -> Form b
setSaving form =
    form
    |> (\f -> { form | state = Saving } )
    |> (\f -> { form | httpErr = "" } )


-- TEMP
{-| Convenience function that sets the form to Done.
-}
setDone : Form b -> Form b
setDone form =
    form
    |> (\f -> { form | state = Done } )



{-| Checks whether a form itself can be updated at all.
If you want to check if a field within a particular form can be updated, use `isFieldUpdatable`.
-}
isUpdatable : Form b -> Bool
isUpdatable form =
    form.updatesEnabled && (not <| List.member form.state [Saving, Done])

{-| Checks whether a field in a form can be updated at all.
-}
isFieldUpdatable : Form b -> Field a -> Bool
isFieldUpdatable form field =
    let
        updatesEnabledInState = not <| List.member form.state [Saving, Done]
    in
        form.updatesEnabled && field.updatesEnabled && updatesEnabledInState


isSubmissible : Form b -> Bool
isSubmissible form =
    isValid form && (not <| List.member form.state [Saving, Done])

{-| Designed to absorb a Field value coming from an input's event handler and do nothing with it,
only returning the already existing form with the already existing fields that it contains.
-}
dontUpdateField : Form b -> a -> Form b
dontUpdateField form val = form



{-| TEMP: puts an HTTP error message into the errMsg of the form.
-}
addHttpErr : String -> Form b -> Form b
addHttpErr httpErrMsg form =
    form
    |> (\f -> { form | httpErr = httpErrMsg } )

















{-| Validates every `Field` of a `Form`, then validates the whole `Form` itself.
```
-}
validate : Form b -> Form b
validate form =
    let
        -- validate each field individually first
        newVals = form.fieldValidation form.value
        newModel = { form | value = newVals }
    in
        -- validate the whole field structure
        Validatable.validateAndToggleErr newModel



{-| Validates a field in a form value (and shows errs depending on it's behaviour).

Currently a weird stopgap to streamine fieldValidation in a Form type.
-}
validateField : FieldGetter a b
                -> FieldSetter a b
                -> b
                -> b
validateField getter setter formVal =
    formVal
    |> getter
    |> Validatable.validateAndShowErr
    |> setter formVal
















-- moving data around -------------------------------------------------



{-| A function that sets a Field to a `Form`'s `.value`.
-}
type alias FieldSetter a b = b -> Field a -> b

{-| A function that gets a Field from a `Form`'s `.value`.
-}
type alias FieldGetter a b = b -> Field a

{-| A msg for changing a form.
-}
type alias FormChanger b msg = Form b -> msg

{-| Gets a `Field` from a `Form` via a `FieldGetter` (ie. `.username`).
-}
getField : FieldGetter a b -> Form b -> Field a
getField accessor form = accessor form.value

{-| Gets a `Field`'s value from a `Form` via a `FieldGetter` (ie. `.username`).
-}
getFieldVal : FieldGetter a b -> Form b -> a
getFieldVal accessor form =
    let
        field = accessor form.value
    in
        field.value














-- event handlers -------------------------------------------------


{-| Takes an `(a -> msg)`, updates the `Field` value to that `a` and performs
validation on both the field and the form.

(This is intended to be used in event handlers that return values, like `onInput`.)

- `a` is the `Field` data type.
- `b` is the `Form` data type.

```
    Html.input
        (   [ class "ps--text-input"
            , type_ "text"
            , onInput <| Form.updateField field form setter onChange
        )
        [ Html.text field.value ]
```

Will make no change or validation if either the form or field has been disabled.
-}
updateField : Field a
            -> Form b
            -> FieldSetter a b
            -> (Form b -> msg)
            -> (a -> msg)
updateField field form setter onChange =
    case isFieldUpdatable form field of
        False -> dontUpdateField form >> onChange
        True ->
            -- Field
            Field.replaceValue field form.updatesEnabled >>
            Validatable.validate >>
            -- Form values
            setter form.value >>
            -- Form
            replaceValues form >>
            Validatable.validateAndHideErr >>

            onChange



{-| Takes an `(a -> msg)`, updates the `Field` value to
that `a`. This **does not** perform validation.

This is intended to be used in event handlers that return values, like
`onInput`.

The reason this doesn't validate is because some
inputs (like radio buttons) should not need to be validated,
therefore validation does not need to be performed when these certain types of
inputs change.

- `a` is the `Field` data type.
- `b` is the `Form` data type.

Will make no change if either the form or field has been disabled.
-}
updateFieldWithoutValidation : Field a
                            -> Form b
                            -> FieldSetter a b
                            -> (Form b -> msg)
                            -> (a -> msg)
updateFieldWithoutValidation field form setter onChange =
    case isFieldUpdatable form field of
        False -> dontUpdateField form >> onChange
        True ->
            -- Field
            Field.replaceValue field form.updatesEnabled >>
            -- Form values
            setter form.value >>
            -- Form
            replaceValues form >>
            onChange




{-| Takes a `(msg)`, updates the `Field` value with a specific value given to it
and performs validation on both the field and the form.

(This is intended to be used in event handlers that don't return values but
need something passed to identify what has changed, like `onClick` in radio inputs.)

- `a` is the `Field` data type.
- `b` is the `Form` data type.

```
    Html.input
        (   [ class "ps--text-input"
            , type_ "text"
            , onInput <| Form.updateField field form setter onChange
        )
        [ Html.text field.value ]
```

Will make no change or validation if either the form or field has been disabled.
-}
updateFieldManually : a
                    -> Field a
                    -> Form b
                    -> FieldSetter a b
                    -> (Form b -> msg)
                    -> msg
updateFieldManually newValue field form setter onChange =
    case isFieldUpdatable form field of
        False -> onChange form -- dont update or validate
        True ->
            newValue
            -- Field
            |> Field.replaceValue field form.updatesEnabled
            |> Validatable.validate
            -- Form values
            |> setter form.value
            -- Form
            |> replaceValues form
            |> Validatable.validateAndHideErr

            |> onChange




{-| updateFieldWithValue but does not perform validation.

This is intended to be used in event handlers that don't return values but
need something passed to identify what has changed, like `onClick` in radio inputs.

The reason this doesn't validate is because some
inputs (like radio buttons) should not need to be validated,
therefore validation does not need to be performed when these certain types of
inputs change.

Will make no change if either the form or field has been disabled.
-}
updateFieldManuallyWithoutValidation : a
                                    -> Field a
                                    -> Form b
                                    -> FieldSetter a b
                                    -> (Form b -> msg)
                                    -> msg
updateFieldManuallyWithoutValidation newValue field form setter onChange =
    case isFieldUpdatable form field of
        False -> onChange form -- dont update
        True ->
            newValue
            -- Field
            |> Field.replaceValue field form.updatesEnabled
            -- Form values
            |> setter form.value
            -- Form
            |> replaceValues form

            |> onChange







{-| The series of basic data transformations that to be done to a `Form`
the time the user performs an action that is meant to validate the form
and trigger any potential validation errors to show.

(This should be used in event handlers that don't give a value,
like `onBlur`.)

- `a` is the `Field` data type.
- `b` is the `Form` data type.

```
    Html.input
        (   [ class "ps--text-input"
            , type_ "text"
            , onInput <| Form.updateField field form setter onChange
            , onBlur <| Form.showAnyFieldErr field form setter onChange
            ]
        )
        [ Html.text field.value ]
```

Will make no changes if either the form or field has been disabled.
-}
showAnyFieldErr : Field a
                -> Form b
                -> FieldSetter a b
                -> (Form b -> msg)
                -> msg
showAnyFieldErr field form setter onChange =
    case isFieldUpdatable form field of
        False -> onChange form -- dont update or validate
        True ->
            onChange
            -- Form
            <| Validatable.validateAndHideErr
            <| replaceValues form
            -- Form value
            <| setter form.value
            -- Field
            <| Validatable.possiblyShowErr
            <| Validatable.validate field






{-| Starts the process of submitting the form.
-}
submit : Form b
        -> (Form b -> msg)
        -> (Form b -> msg)
        -> msg
submit form changeMsg submitMsg =
    case isUpdatable form of
        False -> changeMsg form
        True ->
            let
                -- check to see if the form is valid
                -- one last time before moving on
                validatedForm = validate form
            in
                case isSubmissible validatedForm of
                    -- success
                    True -> submitMsg validatedForm
                    -- fail
                    False -> changeMsg validatedForm
