module Form.Validator exposing ( Validator
                               , ValidatorSet(..)
                               , create

                               , hasFailed
                               , hasPassed
                               , evaluateSet

                               , isNotEmpty
                               , hasMaxLength
                               , hasLengthBetween
                               , isValidEmail
                               , hasOnlyAlphanumeric
                               , hasOnlyAlphanumericOrUnderscores

                               , isNotNothing
                               , isTrue
                               )

{-| The foundation for validating Validatables.

# Data Types
@docs Validator, ValidatorSet

# Creating Validators
@docs create

# Validation
@docs hasFailed, hasPassed, evaluateSet

# Validators

## String validators
@docs isNotEmpty, hasMaxLength, hasLengthBetween, isValidEmail, hasOnlyAlphanumeric, hasOnlyAlphanumericOrUnderscores

## Other Validators
@docs isNotNothing, isTrue

-}


import Regex exposing (Regex)


{-| A tuple containing a function that takes a value
and evaluates it as valid (True) or not valid (False), and a string
for the validation error message for displaying to the user when
the input is invalid.

You generally don't want to use a `Validator` on it's own. It should be utilised as part of a `ValidatorSet`.
-}
type alias Validator a =
    ( a -> Bool, String)


{-| A simple constructor for a `Validator`.

When making a `Validator`, you should pass the `String` as an option so an
error message can be written in the place in which it gets used.

    containsE = Validator String
    containsE errMsg = Validator.create (\s -> String.contains "e" s == True) errMsg
-}
create : (a -> Bool) -> String -> Validator a
create func errMsg = (func, errMsg)


{-| A type for validating an input's contents in real time
and when to show validation errors to the user.

For the sake of type consistency, you will probably always need a `ValidatorSet` for a user input,
 but not all user inputs actually require validation, so this can be either:

- `DoValidation` (perform validation)
- `PassValidation` (don't actually perform validation and assume its fine).

````

    usernameValidation : ValidatorSet String
    usernameValidation =
        DoValidation
            [ Validator.isNotEmpty "This error message will show to the user first if this fails."
            , Validator.hasMaxStringLength 20 "This will show to the user if the Validator above passes and this fails."
            , Validator.hasOnlyAlphanumericOrUnderscores "This will show to the user if every other Validator passes and this one fails."
            ]

    bioValidation : ValidatorSet String
    bioValidation = PassValidation -- do nothing, assume it's always fine

````
-}
type ValidatorSet a
    = DoValidation (List (Validator a)) -- Perform validation
    | PassValidation -- Assume it's valid under any circumstances



{-| Checks whether a `Validator` has failed.

    hasFailed "ThisIsWayTooLong" (hasMaxLength 15 "This is too long") == True
-}
hasFailed : a -> Validator a -> Bool
hasFailed value validator =
        (Tuple.first validator) value == False

{-| Checks whether a `Validator` has passed.

    hasPassed "TheRightSize" (hasMaxLength 15 "This is too long") == True
-}
hasPassed : a -> Validator a -> Bool
hasPassed value validator =
        (Tuple.first validator) value == True

{-| Function that looks through a `ValidatorSet` with a value,
tests the value against them, and returns a tuple containing
a `Bool` with an error message `String` (if the result is invalid,
else the string will be empty).

(`True` = valid, `False` = invalid)

-}
evaluateSet : ValidatorSet a -> a -> (Bool, String)
evaluateSet vs value =
    let
        -- compile the failed evaluation with the error message.
        compile = (\vali -> (False, Tuple.second vali))

        getFirstFailedValidator = (\valu valis ->
            valis
            |> List.filter (hasFailed valu)
            |> List.map compile
            |> List.head
            )

    in
        case vs of
            PassValidation -> (True, "")
            DoValidation validatorSet ->
                case (getFirstFailedValidator value validatorSet) of
                    Nothing -> (True, "")
                    Just failedValidator -> failedValidator







-- STRING VALIDATORS

{-| A `Validator` that makes sure that a `String` isn't empty.

    Validator.isNotEmpty "This is a required field."
-}
isNotEmpty : String -> Validator String
isNotEmpty errMsg = ( (\v -> String.length v > 0), errMsg )


{-| A `Validator` that makes sure that a `String` has a certain maximum length.

    Validator.hasMaxLength 200 "This is tooooo long."
-}
hasMaxLength : Int -> String -> Validator String
hasMaxLength maxLen errMsg =
    ((\v -> String.length v <= maxLen), errMsg)


{-| A `Validator` that makes sure that a `String` has a certain minimum and maximum length.

    Validator.hasLengthBetween 20 200 "This must be between 20 and 200 characters long."
-}
hasLengthBetween : Int -> Int -> String -> Validator String
hasLengthBetween minLen maxLen errMsg =
    ((\v -> String.length v >= minLen && String.length v <= maxLen), errMsg)


{-| A `Validator` that makes sure that a `String` is a valid email address.

    Validator.isValidEmail "This must be a valid email address."
-}
isValidEmail : String -> Validator String
isValidEmail errMsg = ((\v -> Regex.contains validEmail v ), errMsg )


{-| A `Validator` that makes sure that a `String` only contains alphanumeric characters (A-Z, a-z, 0-9).

    Validator.hasOnlyAlphanumeric "This must only contain letters or numbers."
-}
hasOnlyAlphanumeric : String -> Validator String
hasOnlyAlphanumeric errMsg =
    ((\v -> Regex.contains onlyAlphanumericChars v), errMsg)


{-| A `Validator` that makes sure that a `String` only contains alphanumeric
characters (A-Z, a-z, 0-9) or underscores.

    Validator.hasOnlyAlphanumericOrUnderscores "This must only contain letters, numbers or underscores."
-}
hasOnlyAlphanumericOrUnderscores : String -> Validator String
hasOnlyAlphanumericOrUnderscores errMsg =
    ((\v -> Regex.contains onlyAlphanumericOrUnderscoreChars v), errMsg)




-- OTHER VALIDATORS


{-| A `Validator` that makes sure a `Maybe a` isn't Nothing.

    Validator.isNotNothing "You must pick an option."
-}
isNotNothing : String -> Validator (Maybe a)
isNotNothing errMsg = ( (\v -> v /= Nothing), errMsg )

{-| A `Validator` that makes sure that a `Bool` is True.

    Validator.isTrue "You must agree to our Terms of Service."
-}
isTrue : String -> Validator Bool
isTrue errMsg = ( (\v -> v == True), errMsg )














-- INTERNAL HELPER REGEXES

{-| The regex used by isValidEmail.
-}
validEmail : Regex
validEmail =
    "^[a-zA-Z0-9.!#$%&'*+\\/=?^_`{|}~-]+@[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(?:\\.[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)*$"
        |> Regex.fromStringWith { caseInsensitive = True, multiline = False }
        |> Maybe.withDefault Regex.never

{-| The regex used by hasOnlyAlphanumeric.
-}
onlyAlphanumericChars : Regex
onlyAlphanumericChars =
    "^([A-Za-z0-9])+$"
        |> Regex.fromStringWith { caseInsensitive = False, multiline = False }
        |> Maybe.withDefault Regex.never

{-| The regex used by hasOnlyAlphanumericOrUnderscores.
-}
onlyAlphanumericOrUnderscoreChars : Regex
onlyAlphanumericOrUnderscoreChars =
    "^([A-Za-z0-9_])+$"
        |> Regex.fromStringWith { caseInsensitive = False, multiline = False }
        |> Maybe.withDefault Regex.never
