# Make a TABLE_ID from a vector of xpaths

The number is always nine digits in groups of three, so IDs sort as text
in the same order as the repeats they number. Five digits used to be the
minimum width, not a cap, and a filing with 100,000+ repeats produced
`TID-100000`, which sorts before `TID-20000` (EF2-17).

## Usage

``` r
get_table_id(xpaths)
```

## Arguments

- xpaths:

  Character vector of xpaths.

## Value

Character vector like "TID-000-000-003".
