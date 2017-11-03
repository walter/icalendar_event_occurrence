defmodule ICalendarEventOccurrenceTest do
  use ExUnit.Case, async: true

  alias ICalendar.{Event, Event.Occurrence, RRULE}

  describe "ICalendar.Event.Occurrence.occurrences/1 when a single event given" do
    setup :event

    test "returns list with only single occurrence when given event has no rrule", %{event: event} do
      assert Occurrence.occurrences(event) == [event]
    end

    test "returns list with daily occurrences when given event has simple daily until rrule", %{event: event} do
      rrule = %RRULE{frequency: :daily, until: Timex.to_datetime({{2016, 7, 7}, {7, 7, 7}}, "UTC")}
      event = %{event | rrule: rrule}

      result = Occurrence.occurrences(event)

      assert Enum.count(result) == 32
      assert List.last(result).dtstart == Timex.to_datetime({{2016, 7, 7}, {6, 6, 6}}, "UTC")
    end

    test "returns list with daily occurrences when given event has simple daily count rrule", %{event: event} do
      rrule = %RRULE{frequency: :daily, count: 2}
      event = %{event | rrule: rrule}

      result = Occurrence.occurrences(event)

      assert Enum.count(result) == 2
      assert List.last(result).dtstart == Timex.to_datetime({{2016, 6, 7}, {6, 6, 6}}, "UTC")
    end

    test "returns list with weekly occurrences when given event has simple weekly until rrule", %{event: event} do
      rrule = %RRULE{frequency: :weekly, until: Timex.to_datetime({{2016, 7, 7}, {7, 7, 7}}, "UTC")}
      event = %{event | rrule: rrule}

      result = Occurrence.occurrences(event)

      assert Enum.count(result) == 5
      assert List.last(result).dtstart == Timex.to_datetime({{2016, 7, 4}, {6, 6, 6}}, "UTC")
    end

    test "returns list with weekly occurrences when given event has simple weekly count rrule", %{event: event} do
      rrule = %RRULE{frequency: :weekly, count: 2}
      event = %{event | rrule: rrule}

      result = Occurrence.occurrences(event)

      assert Enum.count(result) == 2
      assert List.last(result).dtstart == Timex.to_datetime({{2016, 6, 13}, {6, 6, 6}}, "UTC")
      assert Timex.format(event.dtstart, "%a", :strftime) == Timex.format(List.last(result).dtstart, "%a", :strftime)
    end

    test "returns list with weekly occurrences when given event has weekly until rrule with by_day" do
      until = Timex.to_datetime({{2016, 1, 7}, {6, 6, 6}}, "UTC")
      dtstart = Timex.shift(until, weeks: -2)
      dtend = Timex.shift(dtstart, hours: 1)
      rrule = %RRULE{frequency: :weekly, by_day: [:monday, :tuesday, :thursday], until: until}
      event = %Event{dtstart: dtstart, dtend: dtend, rrule: rrule}

      result = Occurrence.occurrences(event)

      assert Enum.count(result) == 7
      assert List.last(result).dtstart == until
    end

    test "returns list with weekly occurrences when given event has weekly count rrule with by_day", %{event: event} do
      rrule = %RRULE{frequency: :weekly, by_day: [:tuesday, :thursday], count: 10}
      event = %{event | rrule: rrule}

      result = Occurrence.occurrences(event)

      assert Enum.count(result) == 10
      # cannot rely on order yet
      # assert List.last(result).dtstart == Timex.to_datetime({{2016, 7, 7}, {6, 6, 6}}, "UTC")
    end

    test "returns list with monthly occurrences when given event has simple monthly until rrule", %{event: event} do
      until = Timex.to_datetime({{2016, 8, 6}, {6, 6, 6}}, "UTC")
      rrule = %RRULE{frequency: :monthly, until: until}
      event = %{event | rrule: rrule}

      result = Occurrence.occurrences(event)

      assert Enum.count(result) == 3
      assert List.last(result).dtstart == until
    end

    test "returns list with monthly occurrences when given event has simple monthly count rrule", %{event: event} do
      rrule = %RRULE{frequency: :monthly, count: 2}
      event = %{event | rrule: rrule}

      result = Occurrence.occurrences(event)

      assert Enum.count(result) == 2
      assert List.last(result).dtstart == Timex.to_datetime({{2016, 7, 6}, {6, 6, 6}}, "UTC")
    end

    test "returns list with monthly occurrences when given event has monthly until rrule with by_month_day", %{event: event} do
      until = Timex.to_datetime({{2016, 7, 6}, {6, 6, 6}}, "UTC")
      rrule = %RRULE{frequency: :monthly, by_month_day: [6, 7, 8], until: until}
      event = %{event | rrule: rrule}

      result = Occurrence.occurrences(event)

      assert Enum.count(result) == 4
      assert List.last(result).dtstart == until
    end

    test "returns list with monthly occurrences when given event has monthly count rrule with by_month_day", %{event: event} do
      rrule = %RRULE{frequency: :monthly, by_month_day: [7, 8], count: 4}
      event = %{event | rrule: rrule}

      result = Occurrence.occurrences(event)

      assert Enum.count(result) == 4
      assert List.last(result).dtstart == Timex.to_datetime({{2016, 7, 7}, {6, 6, 6}}, "UTC")
    end
  end

  describe "ICalendar.Event.Occurrence.occurrences/1 when list of events are given" do
    test "returns only occurrences where events have no rrule" do
      start = Timex.shift(DateTime.utc_now, months: -1)
      event = %Event{dtstart: start, dtend: Timex.shift(start, hours: 1)}

      assert Occurrence.occurrences([event]) == [event]
    end

    test "returns only occurrences that are before now" do
      future_start = Timex.shift(DateTime.utc_now, months: 1)
      event_future = %Event{dtstart: future_start, dtend: Timex.shift(future_start, hours: 1)}
      past_start = Timex.shift(DateTime.utc_now, months: -1)
      event_past = %Event{dtstart: past_start, dtend: Timex.shift(past_start, hours: 1)}

      assert Occurrence.occurrences([event_past, event_future]) == [event_past]
    end
  end

  describe "ICalendar.Event.Occurrence.occurrences/2 when list of events are given" do
    test "returns only occurrences that are before end_datetime" do
      end_datetime = Timex.shift(DateTime.utc_now, months: 1)

      over_start = Timex.shift(DateTime.utc_now, months: 2)
      event_over = %Event{dtstart: over_start, dtend: Timex.shift(over_start, hours: 1)}
      under_start = Timex.shift(DateTime.utc_now, days: 14)
      event_under = %Event{dtstart: under_start, dtend: Timex.shift(under_start, hours: 1)}


      assert Occurrence.occurrences([event_under, event_over], end_datetime) == [event_under]
    end
  end

  defp event(_context) do
    dtstart = Timex.to_datetime({{2016, 6, 6}, {6, 6, 6}}, "UTC")
    [event: %Event{dtstart: dtstart, dtend: Timex.shift(dtstart, hours: 1)}]
  end
end
