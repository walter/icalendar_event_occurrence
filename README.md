# ICalendar Event Occurrence

Defines `ICalendar.Event.Occurrence` as set of utilities for mapping
occurrences for a given event as discussed here:

https://github.com/lpil/icalendar/issues/5

For an event that may have `dtstart`, `dtend`, and `rrule` derived
occurrences.

May just be single occurrence if no rrule.

Initial work based on [`ExIcal.Recurrence`](https://github.com/fazibear/ex_ical).

## Usage

There is a lot of possible event composition scenarios for generating
occurrences! Check out the tests for more examples.

```Elixir
  alias ICalendar.{Event, Event.Occurrence, RRULE}

  dtstart = Timex.to_datetime({{2017, 1, 1}, {0, 0, 1}}, "UTC")
  dtend = Timex.shift(dtstart, hours: 1)
  until = Timex.to_datetime({{2017, 12, 31}, {23, 59, 59}}, "UTC")

  rrule = %RRULE{frequency: :daily, until: until}

  event = %Event{dtstart: dtstart, dtend: dtend, rrule: rrule}

  # with default end_datetime of now
  # so occurrences up to now
  event |> Occurrence.occurrences()

  # or you can specify an end_datetime
  # good for generating occurrences for a recurring event up to a
  # point in the future

  end_datetime = Timex.shift(DateTime.utc_now, years: 1)

  event |> Occurrence.occurrences(end_datetime)

```

## WARNING

This is a pre-release work-in-progress that has a dependency on an
unmerged walter/icalendar:feature/rrule branch version of
icalendar. Use at your own risk.

## Installation

The package can be installed by adding `icalendar_event_occurrence` to your
list of dependencies in `mix.exs` via github:

```elixir
def deps do
  [
    {:icalendar_event_occurrence, github: "walter/icalendar_event_occurence"}
  ]
end
```
