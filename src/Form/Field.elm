module Form.Field exposing ( Field
                          , empty
                          , prefilled
                          , prefilledDisabled

                          , getValue
                          , replaceValue
                          )

{-| A module that encapsulates user-submitted data with Validatable metadata.

# Field
@docs Field

# Creating Fields
@docs empty, prefilled, prefilledDisabled

# Manipulation
@docs getValue, replaceValue

-}

import Form.Validatable exposing ( Validity(..)
                                 , ErrVisibility(..)
                                 , ErrBehavior(..)
                                 )

import Form.Validator exposing (ValidatorSet(..))








{-| A data type enclosing user inputs alongside validation information
on that input.

See `Form.Validatable.Validatable` to understand most of this record structure.

A thing that isn't in Validatable:
- updatesEnabled : Boolean saying explicitly whether or not the user can edit
the field right now. It should be tied to a visual disabled state in the
input itself (but not the HTML `disabled` attribute - it's not screenreader friendly.)
-}
type alias Field a =
    { value : a
    , validators : ValidatorSet a

    , validity : Validity
    , errMsg : String
    , errVisibility : ErrVisibility
    , errBehavior : ErrBehavior

    , updatesEnabled : Bool
    }

{-| Creates a `Field` that is set up in a state which assumes
that the user hasn't filled in this particular data point yet (therefore, it is `Unchecked`).

Because there are many possible representations of what empty is,
you have to enter in what 'empty' means for the value itself.

A `Field.empty` should always be used inside a `Form.empty`.

    initModel : Model
    initModel =
        { registerForm = Form.empty registerValidators { username = Field.empty usernameValidators ""
                                                        , email = Field.empty emailValidators  ""
                                                        , tos = Field.empty tosValidators False
                                                        }
        }

-}
empty : ValidatorSet a -> a -> Field a
empty valis val =
    { value = val
    , validators  = valis

    , validity = Unchecked
    , errMsg = ""
    , errVisibility = HideErr
    , errBehavior = RevealedValidation

    , updatesEnabled = True
    }


{-| Creates a `Field` that is set up in a state which assumes
that the user has filled in this data point before and that it's `Valid`.

Designed for `Form`s that a user is returning to.

Because it's assumed the user is returning to it, validation errors will
show immediately.

A `Field.prefilled` should always be used inside a `Form.prefilled`.

    initModel : Model
    initModel =
        { profileForm = Form.prefilled profileValidators { displayName = Field.prefilled displayNameValidators "Dzuk"
                                                           , bio = Field.prefilled bioValidators "Big gay orc."
                                                           , botAccount = Field.prefilled PassValidation False
                                                           , adultAccount = Field.prefilled PassValidation False
                                                           }
        }

-}
prefilled : ValidatorSet a -> a -> Field a
prefilled valis val =
    { value = val
    , validators  = valis

    , validity = Valid
    , errMsg = ""
    , errVisibility = ShowErr
    , errBehavior = AlwaysValidation

    , updatesEnabled = True
    }


{-| Creates a prefilled `Field` that is disabled.
-}
prefilledDisabled : ValidatorSet a -> a -> Field a
prefilledDisabled valis val =
    { value = val
    , validators  = valis

    , validity = Valid
    , errMsg = ""
    , errVisibility = ShowErr
    , errBehavior = AlwaysValidation

    , updatesEnabled = False
    }


{-| Returns a field's value.

    fieldy = Field.prefilled "Hi"

    Field.getValue fieldy == "Hi"
-}
getValue : Field a -> a
getValue field = field.value



{-| Take a Field, and replaces it's value with the one given.

    fieldy = Field.prefilled "Hi"

    getValue fieldy == "Hi"
    getValue <| replaceValue fieldy "Bye" == "Bye"

    Requires that updates are enabled on both the field
    itself and the form encapsulating it (represented
    by the bool input). If updates are disabled on either,
    then the Field will not update.
-}
replaceValue : Field a -> Bool -> a -> Field a
replaceValue field formUpdatesEnabled val =
    case formUpdatesEnabled of
        False ->
            field
        True ->
            case field.updatesEnabled of
                False ->
                    field
                True ->
                    { field | value = val }
