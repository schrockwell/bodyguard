# Changelog

### Legend

- **Fix:** no API change; fixing code to intended behavior
- **Addition:** addition to API
- **Deprecation:** addition to API; old behavior maintained with deprecation warning
- **Change:** breaking change to API

## v2.4.2 - 2021-10-22

- **Addition:** Support string actions
- **Fix:** Get `:default_error` configuration at runtime

## v2.4.1 - 2021-02-16

- **Fix:** `Bodyguard.scope/4`: Don't try to infer schema if an explicit value if provided

## v2.4.0 - 2019-08-04

- **Addition:** Adding ability to specify `{module, function}` for plug's value getters
- **Addition:** Adding default config options for Authorize plug

## v2.3.0 - 2019-07-26

- **Addition:** Adding ability to specify function for plug's `:params` option
- **Addition:** Adding `:default_error` config option (defaults to `:unauthorized`)
- **Fix:** Conforming to `init/1` return typespec for older versions of Plug

## v2.2.4 - 2019-07-15

- **Fix:** #58 Replacing deprecated Phoenix render function

## v2.2.3 - 2018-11-21

- **Fix:** Adding support for Ecto 3 queries

## v2.2.2 - 2018-01-28

- **Fix:** Fixing typespecs #43

## v2.2.1 - 2017-12-20

- **Addition:** Adding ability to specify function for plug's `:action` option f4033852a8ad2bbd48c54766086d7dd2e8dae8f8

## v2.2.0 - 2017-11-26

- **Deprecation:** Moving user-specified options to explicit `opts` argument #40

## v2.1.2 - 2017-08-05

- **Deprecation:** Deprecating `use Bodyguard.Policy` and `use Bodyguard.Schema` in favor of straight `defdelegate` dc56221fedfa071f97fba760ff84e591349518e0

## v2.1.1 - 2017-07-26

- **Fix:** Fixing typespecs #35

## v2.1.0 - 2017-07-22

- **Addition:** Allowing boolean results from `authorize/3` callbacks #32

## v2.0.1 - 2017-07-05

- **Fix:** Fixing handling of plug's `:user` option #28

## v2.0.0 - 2017-06-30

- **Change:** Using new context-based API
