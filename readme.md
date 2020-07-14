# Realtime Forms

![An gif showing an example field where the user tries to enter a username that doesn't meet different expectations and errors show underneath specifying each error that is made in realtime.](example.gif)

A work-in-progress system for creating form logic where validation is:

- **Contextual** (errors are displayed where they are needed, usually at the input itself)
- **Granular** (errors tell the user exactly what error they made)
- **Realtime** (errors can display as the user is inputting data, not when they try to submit, you can set to trigger realtime validation at different points of a user's interaction so errors aren't shown immediately)

This module only handles the data structures and validation processes, and then you can then insert those things into your own UI stuff.

I've spent quite a long time trying to refine this quite a lot before publishing, but this package should still be considered an early project. It has plenty of flaws in it's current state, like it relies on quite a lot of boilerplate to function, as well as lens-style getters/setters to accomplish a lot of things.

I'm publishing this at the moment in case anyone is interested in this kind of functionality as well as to get feedback. I've decided to not publish this on Elm packages yet because it still might be rough around the edges.

---

## How to use

Check out [realtime-forms-example](https://github.com/dzuk-mutant/realtime-forms-example) for an example of this code in practice.

---


## Improvement goals

- Reduce the amount of input boilerplate ie. all of the arguments that have to be used in functions like `Form.updateField` and `Form.validateField`.
	- This might not be possible given that the form system has to manage multiple data types.
- Generally improve some data structures, particularly when it comes to HTTP-related errors.
- Enable HTTP requests on individual form changes, like a username form that tells someone whether a  username has been taken or not without needing to make a submission attempt first.

---

## License

realtime-forms is licensed BSD-3-Clause