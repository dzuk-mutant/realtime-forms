module Form exposing ( Form
                     , empty
                     , prefilled

                     , replaceValues

                     , State(..)
                     , changeState
                     , setDone
                     , setSaving

                     , validate
                     , validateField

                     , FieldGetter
                     , FieldSetter
                     , getField
                     , getFieldVal

                     , isUpdatable
                     , isFieldUpdatable
                     , updateField
                     , updateFieldManually
                     , showAnyFieldErr

                     , isSubmissible
                     , submit
                     , addHttpErr
                     )

{-| Setting up, manipulating and handling forms.


# Form
@docs Form

# Creating Forms
@docs empty, prefilled

# Manipulating form values
@docs replaceValues

---

# Validation
@docs validate

## Validation in all-field Validation
@docs validateField

---

# Form lifecycle
@docs State, changeState, setDone, setSaving

---

# Field access
Types and functions for accessing and handling `Field` values within a `Form`.

Basically lenses. I'm so sorry.
@docs FieldGetter, FieldSetter, getField, getFieldVal

---

# Updating forms

## Showing restricted user updates
Forms and Fields have internal values that determine
whether a user can edit certain fields, or the entire form. These functions
help you quickly check that, as well as display that information to the
user in your UI.

@docs isUpdatable, isFieldUpdatable


## Performing user input updates
In order to update and validate a user's input in realtime, the functions
that do this work need to be attached to the event handlers of the inputs
the user is using.


@docs updateField, updateFieldManually, showAnyFieldErr

---

# Submitting forms
## Checking before submission
@docs isSubmissible

## Submission
@docs submit

## Displaying HTTP errors
@docs addHttpErr


-}



import Form.Field as Field exposing (Field)
import Form.Updatable as Updatable
import Form.Validatable as Validatable exposing (ErrBehavior(..), ErrVisibility(..), Validity(..), isValid, validate)
import Form.Validator exposing (ValidatorSet(..))


{-| A type that represents your whole form, including it's validation state.

See `Form.Validatable.Validatable` to understand most of this record structure,
for the things that aren't in Validatable:

- `updatesEnabled` : Boolean saying explicitly whether or not the user can edit or submit the form right now.
- `state` : A custom type (State) describing what stage of the form lifecycle the form is at.
May also dictate whether or not the user can edit or submit.
- `httpErr` : A temporary fix for now for how to display HTTP errors to the user when a form fails to be submitted.
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

A `Form.empty` should always contain empty Fields.

    initModel : Model
    initModel =
        { registerForm = Form.empty registerValidators registerFieldValidation
                                        { username = Field.empty usernameValidators ""
                                        , email = Field.empty emailValidators  ""
                                        , tos = Field.empty tosValidators False
                                        }
        }

The arguments:
- ValidatorSet for the form itself
- A function that goes through every Field in this Form that needs validating and validates them (currently necessary boilerplate)
- The nested Fields.


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

Designed for forms that a user is returning to. It should contain prefilled Fields.

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

The arguments:
- ValidatorSet for the form itself
- A function that goes through every Field in this Form that needs validating and validates them (currently necessary boilerplate)
- The nested Fields.

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
               , bio = Field.prefilled "Meh."
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

- `Unsaved` : The form (in it's current state) has not been saved.
- `Saving` : The form is being sent to the server.
User access should be disabled.
- `Saved` : The form (in it's current state) has been saved and can be entered
by the user again.
- `Done` : The form has been complete and sent, and the user should not enter
anything more and the UI should move onto something else. User access should be disabled.


It doesn't encapsulate one lifecycle, but two potentially different ones.

### One-time form
A form a user completes once and then doesn't interact with again.

1. `Unsaved`
2. `Saving` (user has clicked the submit button)
3. then either...
    - `Done` (submission successful, user cannot edit anymore, the UI moves on)
    - `Unsaved` (subumission unsuccessful, user can edit and try to submit again)


### Returning form
A form a user can keep returning to after they have saved it (like a settings form).

1. `Unsaved`
2. `Saving` (user has clicked the submit button)
3. then either...
    - `Saved` (submission successful, user can edit and submit again)
    - `Unsaved` (subumission unsuccessful, user can edit and try to submit again)

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





















-- validation -------------------------------------------------


{-| Validates every `Field` of a `Form`, then validates the whole `Form` itself.

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
















-- getters and setters -------------------------------------------------


{-| A function that sets a Field to a Form's value (`b`).
-}
type alias FieldGetter a b = b -> Field a

{-| A function that sets a Field to a Form's value (`b`).
-}
type alias FieldSetter a b = b -> Field a -> b

{-| Gets a Field from a Form via a Field's record accessor (ie. `.username`).

```
    getField .username registerForm
```
-}
getField : FieldGetter a b -> Form b -> Field a
getField accessor form = accessor form.value

{-| Gets a Field's value from a Form via a Field's record accessor (ie. `.username`).

```
    getField .email registerForm
```
-}
getFieldVal : FieldGetter a b -> Form b -> a
getFieldVal accessor form =
    let
        field = accessor form.value
    in
        field.value












-- update stuff -------------------------------------------------

{-| Checks whether a form itself can be updated at all.

For instance, if a form is not updatable, you can use this function to
make it's associated submit/save button show a disabled visual state.

-}
isUpdatable : Form b -> Bool
isUpdatable form =
    form.updatesEnabled && (not <| List.member form.state [Saving, Done])

{-| Checks whether a field in a form can be updated at all.

For instance, if a field is not updatable (or the form the field is a part of),
you can use this function to make it's associated input show a disabled visual state.
-}
isFieldUpdatable : Form b -> Field a -> Bool
isFieldUpdatable form field =
    let
        updatesEnabledInState = not <| List.member form.state [Saving, Done]
    in
        form.updatesEnabled && field.updatesEnabled && updatesEnabledInState



{-| Internal helper designed to absorb a Field value coming from an input's
event handler and do nothing with it, only returning the already existing
form with the already existing fields that it contains.
-}
dontUpdateField : Form b -> a -> Form b
dontUpdateField form val = form


-- event handlers -------------------------------------------------


{-| Takes an `(a -> msg)`, updates the `Field` value to that `a` and performs
validation on both the field and the form.

This is intended to be used in event handlers that return values the user
directly inputs, like `onInput` in text inputs and `onCheck` in checkboxes.

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





{-| This updates and validates a field, but you provide the value that it's
being updated to yourself. This is necessary for things like `onClick` in radio buttons.

- `a` is the `Field` data type.
- `b` is the `Form` data type.

```
Html.input
    [ type_ "radio"
    , onClick <| Form.updateFieldManually val field form fieldSetter onChange
    ]
    []
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










-- submission stuff -------------------------------------------------


{-| Checks whether the form in it's current state can be submitted by the user.
-}
isSubmissible : Form b -> Bool
isSubmissible form =
    isValid form && (not <| List.member form.state [Saving, Done])



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


{-| TEMP: puts an HTTP error message into the errMsg of the form.
-}
addHttpErr : String -> Form b -> Form b
addHttpErr httpErrMsg form =
    form
    |> (\f -> { form | httpErr = httpErrMsg } )
