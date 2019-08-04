### Legend

* **Fix:** no API change; fixing code to intended behavior
* **Addition:** addition to API
* **Deprecation:** addition to API; old behavior maintained with deprecation warning
* **Change:** breaking change to API

# Bodyguard Changelog

## v2.4.0

* **Addition:** Adding ability to specify `{module, function}` for plug's value getters
* **Addition:** Adding default config options for Authorize plug

## v2.3.0

* **Addition:** Adding ability to specify function for plug's `:params` option  
* **Addition:** Adding `:default_error` config option (defaults to `:unauthorized`)
* **Fix:** Conforming to `init/1` return typespec for older versions of Plug

## v2.2.4

* **Fix:** #58 Replacing deprecated Phoenix render function

## v2.2.3

* **Fix:** Adding support for Ecto 3 queries

## v2.2.2

* **Fix:** Fixing typespecs #43

## v2.2.1

* **Addition:** Adding ability to specify function for plug's `:action` option f4033852a8ad2bbd48c54766086d7dd2e8dae8f8

## v2.2.0

* **Deprecation:** Moving user-specified options to explicit `opts` argument #40

## v2.1.2
* **Deprecation:** Deprecating `use Bodyguard.Policy` and `use Bodyguard.Schema` in favor of straight `defdelegate` dc56221fedfa071f97fba760ff84e591349518e0

## v2.1.1

* **Fix:** Fixing typespecs #35

## v2.1.0

* **Addition:** Allowing boolean results from `authorize/3` callbacks #32

## v2.0.1

* **Fix:** Fixing handling of plug's `:user` option #28

## v2.0.0

* **Change:** Using new context-based API