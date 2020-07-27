module Form.Validatable exposing ( Validatable
                                 , Validity(..)
                                 , ErrVisibility(..)
                                 , ErrBehavior(..)

                                 , isValid
                                 , isInvalid
                                 , validityToBool
                                 , boolToValidity
                                 , ifShowErr

                                 , possiblyShowErr
                                 , possiblyHideErr
                                 , possiblyToggleErr
                                 , forceShowErr
                                 , forceHideErr

                                 , validate
                                 , validateAndShowErr
                                 , validateAndHideErr
                                 , validateAndToggleErr
                                 )

{-| The underlying data structure behind Fields and Forms, and how
to manipulate and use the validation state of Forms and Fields.

# Data types
@docs Validatable, Validity, ErrVisibility, ErrBehavior

# Evaluating contents
Checking a `Validatable`'s contents and converting them from certain types.
@docs isValid, isInvalid, ifShowErr, validityToBool, boolToValidity

# Changing error visibility
Making error messages potentially show or hide.
@docs possiblyShowErr, possiblyHideErr, possiblyToggleErr, forceShowErr, forceHideErr

# Validation
@docs validate

## Validation with convenience additions
These functions combine validation with error visibility functions.
@docs validateAndShowErr, validateAndHideErr, validateAndToggleErr
-}


import Form.Validator as Validator exposing (ValidatorSet(..))


{-| This is the basis for the `Form` and `Field` data types.

Validatable is an interface for a record that has a value with validation state and error handling behavior.

- `value` : The value.
- `validators` : The validators for use against the value.
- `validity` : The validity of the value.
- `errMsg` : The current error message related to the value.
- `errVisibility` : Whether or not `errMsg` should be shown to the user.
- `errBehavior` : When and how to set `errVisibility` based on other factors of the Validatable.

`errMsg` is handled in a 'sticky' way - meaning that even if a Validatable
is valid, the `errMsg` will always contain the last known error messge if it has previously been invalid.
This is done so that animated transitions can be
performed on error messages.
-}
type alias Validatable a r =
    { r | value : a
        , validators : ValidatorSet a

        , validity : Validity
        , errMsg : String
        , errVisibility : ErrVisibility
        , errBehavior : ErrBehavior
    }




{-| Custom type for representing validity.

`Unchecked`'s main role is as a blank initial state - for
establishing empty forms that have not been validated beforehand,
but will as soon as the user starts inputting data. (eg. `Form.empty` and `Field.empty` are both `Unchecked`.)
-}
type Validity
    = Valid
    | Invalid
    | Unchecked

{-| Custom type for representing whether a `Validatable` has been
marked to show it's validation error message or not.

Keep in mind that this is simply a marker of intent, because whether
an error should actually show should also depend on whether it's `Invalid`.

Use `ifShowErr` to easily determine whether or not to show a validation error message.
-}
type ErrVisibility
    = ShowErr
    | HideErr


{-| How a validatable should behave when it comes to
showing validation error messages to the user.

- `AlwaysValidation` - The user always sees validation error messages as they occur.
- `RevealedValidation` - Validation messages are hidden by default, until triggered to show. Afer this point, validation messages always show themselves.
- `TriggeredValidation` - Hidden by default until triggered. When the value is valid again, it will not show again until it is triggered again.


How these are used by default in Form and Field:

- `AlwaysValidation` - Used in `Form.prefilled` and `Field.prefilled`. It's assumed the user will want instant feedback on data they've already entered before.
- `RevealedValidation` - Used in `Field.empty`, so the user isn't bothered by error messages when they've only just started.
- `TriggeredValidation` - Used in `Form.empty`, so the user isn't bothered and because error messages constantly on new forms doesn't necessarily look nice.

-}
type ErrBehavior
    = AlwaysValidation
    | RevealedValidation
    | TriggeredValidation








{-| Tests to see if a `Validatable` is `Valid`.

    isValid invalidThing == False
-}
isValid : Validatable a r -> Bool
isValid v = v.validity == Valid

{-| Tests to see if a `Validatable` is `Invalid`.

    isInvalid invalidThing == True
-}
isInvalid : Validatable a r -> Bool
isInvalid v = v.validity == Invalid



{-| A function for evaluating whether something should show a `Validatable`'s
`errMsg` or not.

(If a `Validatable` is `Invalid` and `ShowErr`, then this returns `True`.)

This is useful for toggling invalid classes in your HTML.
```
Html.select
    [ classList [ ("invalid", Validatable.ifShowErr realField) ]
    ]
    [ --- etc.
    ]
```

-}
ifShowErr : Validatable a r -> Bool
ifShowErr o =
    o.validity == Invalid
    && o.errVisibility == ShowErr




{-| Converts a `Validity` to a `Bool`.

This aims for a strict definition of validity, so it
evaluates `Unchecked` as `False`.

    validityToBool Valid == True
    validityToBool Invalid == False
    validityToBool Unchecked == False
-}
validityToBool : Validity -> Bool
validityToBool validity =
    case validity of
        Valid -> True
        Invalid -> False
        Unchecked -> False


{-| Converts a `Bool` to a `Validity`.

This treats `Bool` as a simple mapping to `Valid`/`Invalid`.

    boolToValidity True == Valid
    boolToValidity False == Invalid
-}
boolToValidity : Bool -> Validity
boolToValidity bool =
    case bool of
        True -> Valid
        False -> Invalid







{-| Makes a Validatable show its `errMsg` if it's `validity`
meets certain criteria set out by it's `errBehavior`:

- `AlwaysValidation`: always `ShowErr`.
- `RevealedValidation`/`TriggeredValidation`: it will `ShowErr` if it's anything but `Valid`, and `HideErr` if `Valid`.
-}
possiblyShowErr : Validatable a r -> Validatable a r
possiblyShowErr v =
    let
        maybeShowErr = case v.errBehavior of

            -- always show errors, keep showing errors.
            AlwaysValidation -> ShowErr

            -- In this case, RevealedValidation and TriggeredValidation work the same.
            -- show if *not* Valid, hide if Valid.
            _ ->
                case v.validity of
                    Valid -> HideErr
                    _ -> ShowErr

    in
        { v | errVisibility = maybeShowErr }


{-| Makes a Validatable hide it's error if it's `validity`
meets certain criteria set out by it's `errBehavior`:

- `TriggeredValidation`: `HideErr` if it's `Valid.`
- `AlwaysValidation`/`RevealedValidation`: `ShowErr` if it's anything but `Valid`, and `HideErr` if `Valid`.
-}
possiblyHideErr : Validatable a r -> Validatable a r
possiblyHideErr v =
    let
        maybeShowErr = case v.errBehavior of

            -- always show errors, keep showing errors.
            AlwaysValidation -> ShowErr

            -- pass through what came before, whether ShowErr or HideErr.
            -- (RevealedValidation can only be made to show, not to hide.)
            RevealedValidation -> v.errVisibility

            -- Hide error if Valid.
            TriggeredValidation ->
                case v.validity of
                    Valid -> HideErr
                    _ -> v.errVisibility

    in
        { v | errVisibility = maybeShowErr }

{-| Convenience function that uses possiblyHideErr, then possiblyShowErr.
-}
possiblyToggleErr : Validatable a r -> Validatable a r
possiblyToggleErr v =
    v
    |> possiblyHideErr
    |> possiblyShowErr


{-| Sets a `Validatable`'s `errVisibility` to `ShowErr`, regardless of its `errBehavior`.
-}
forceShowErr : Validatable a r -> Validatable a r
forceShowErr v =
    { v | errVisibility = ShowErr }


{-| Sets a `Validatable`'s `errVisibility` to `HideErr`, regardless of its `errBehavior`.
-}
forceHideErr : Validatable a r -> Validatable a r
forceHideErr v =
    { v | errVisibility = HideErr }













{-| Validates a `Validatable` and sets its `validity` based on the result.

`errMsg` will always be set to what the last validation failure was, even if the
`Validatable` is now `Valid`. This is so error messages can have clean animated transitions.
-}
validate : Validatable a r -> Validatable a r
validate v =
    let
        validation = Validator.evaluateSet v.validators v.value
        validity = boolToValidity <| Tuple.first validation

        -- keep the previous message if it's not invalid so live
        -- helpers can transition out properly.
        errMsg = case validity of
            Invalid -> Tuple.second validation
            _ -> v.errMsg
    in
        v
        |> (\w -> { w | validity = validity })
        |> (\w -> { w | errMsg = errMsg })






{-| Shorthand function that uses `validate`, then `possiblyShowErr`.

-}
validateAndShowErr : Validatable a r -> Validatable a r
validateAndShowErr v =
    v
    |> validate
    |> possiblyShowErr


{-| Shorthand function that uses `validate`, then `possiblyHideErr`.
-}
validateAndHideErr : Validatable a r -> Validatable a r
validateAndHideErr v =
    v
    |> validate
    |> possiblyHideErr

{-| Shorthand function that uses `validate`, then `possiblyToggleErr`.
-}
validateAndToggleErr : Validatable a r -> Validatable a r
validateAndToggleErr v =
    v
    |> validate
    |> possiblyToggleErr
