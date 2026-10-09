# Download, parse, and flatten a single XML filing (with retries)

Download, parse, and flatten a single XML filing (with retries)

## Usage

``` r
get_flat_xml(
  url,
  ccf = NULL,
  retries = 3,
  pause_min = 1,
  pause_max = 4,
  timeout = 120
)
```

## Arguments

- url:

  Character XML URL.

- ccf:

  Optional concordance crosswalk.

- retries:

  Integer retries.

- pause_min, pause_max:

  Random backoff bounds in seconds.

- timeout:

  Seconds before a download attempt is abandoned and retried (EF2-15:
  without one, a stalled connection blocked a worker indefinitely).

## Value

List with FLATXML, ATTRIBUTES, and KEYS (see
[`get_keys()`](https://nonprofit-open-data-collective.github.io/ef2/reference/get_keys.md)).
