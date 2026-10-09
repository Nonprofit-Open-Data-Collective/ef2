# Extract the last bracketed index from an xpath

For an xpath like "`/Return/.../ScheduleO[3]/.../Line[12]`" returns
"12".

## Usage

``` r
get_n(x)
```

## Arguments

- x:

  Character scalar xpath.

## Value

Character index (defaults to "0" if none).
