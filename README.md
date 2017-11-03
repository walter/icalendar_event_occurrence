# ICalendar Event Occurrence

Defines `ICalendar.Event.Occurrence` as set of utilities for mapping
occurrences for a given event as discussed here:

https://github.com/lpil/icalendar/issues/5

For an event that may have dtstart, dtend, and rrule derived occurrences.

May just be single occurrence if no rrule.

Initial work based on [`ExIcal.Recurrence`](https://github.com/fazibear/ex_ical).

## Usage

```Elixir

  # for a single RRULE
  schema "somethings" do
    field :rrule, ICalendar.RRULE.Type
    ...
  end

  # or when allowing for multiple rrules
  schema "somethings" do
    field :rrules, {:array, ICalendar.RRULE.Type}, default: []
    ...
  end

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
