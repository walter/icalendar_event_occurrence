defmodule ICalendar.Event.Occurrence do
  @moduledoc """
  Defines `ICalendar.Event.Occurrence` as set of utilities for mapping
  occurrences for a given event.

  For an event that may have dtstart, dtend, and rrule derived occurrences.

  May just be single occurrence if no rrule.

  Initial work based on [`ExIcal.Recurrence`](https://github.com/fazibear/ex_ical).
  """

  use Timex

  alias ICalendar.{Event, RRULE}

  @doc """
  Get occurrences for event list as a list of events.

  _A note on `count`. Generating `count` based occurrences is faily nuts._

  When we have a complex `RRULE` (multiple by_day values, for example), we
  create a new `ICalendar.Event` with a simplified `RRULE` for each of the
  variations. E.g. if we have `by_day: [:monday, :friday]`, we divide the count
  by 2 as a rough new count and then we create a new base event that is only for
  occurrences on mondays and a new base event that is only for occurrences on
  fridays.

  We recursively accumulate occurrences for those events separately then add
  them together. Finally we sort them by dtstart and lop off the extras.

  Because we spin up multiple base events, it would be difficult to include the
  passed in event in the calculation of count in `add_recurring_events_count`
  because in essence we might create too few occurrences if we did.

  It's not pretty, but neither is mapping the human understanding of time to
  computer programs generally ;)

  """
  # occurrences/1
  # no recurrence, simply return event as only occurrence
  def occurrences(%Event{rrule: nil} = event), do: occurrences([event])

  # we have a single event with rrule that specifies a count
  # get occurrences based on count which requires additional processing
  def occurrences(%Event{rrule: %{count: count} = rrule} = event) when not is_nil(count) do
    # in case of count, we produce slightly more than we need
    # and drop any beyond the original count
    # rememeber the original event is first occurrence towards count
    occurrences = event |> build_occurrences(rrule)
    amount_to_drop = Enum.count(occurrences) - count

    occurrences |> Enum.drop(- amount_to_drop)
  end

  # catchall matching single event with rrule that is not based on count, but until
  def occurrences(%Event{rrule: rrule} = event) do
    event |> build_occurrences(rrule)
  end

  # default to occurrences until now
  def occurrences(events) when is_list(events), do: occurrences(events, DateTime.utc_now)

  # occurrences/2
  def occurrences(%Event{} = event, end_datetime), do: occurrences([event], end_datetime)

  # generate event occurrences based on each passed in event's rrule
  # and then return new collection up to specified end_datetime
  def occurrences(events, end_datetime) when is_list(events) do
    occurrences = events ++ (events |> Enum.reduce([], fn event, revents ->
      case event.rrule do
        nil -> revents
        %{until: nil, count: count} when not is_nil(count) -> revents ++ (event |> add_recurring_events_count(count, end_datetime))
        %{count: nil, until: until} when not is_nil(until) -> revents ++ (event |> add_recurring_events_until(until, end_datetime))
        _ -> revents ++ (event |> add_recurring_events_until(end_datetime))
      end
    end))

    # filter out event occurrences that are after end_datetime (including input)
    occurrences
    |> Enum.filter(fn event -> Timex.compare(event.dtstart, end_datetime) < 1 end)
    |> Enum.sort_by(fn event -> DateTime.to_unix(event.dtstart) end)
  end

  defp add_recurring_events_until(event, until) do
    new_event = event |> shift |> adjust_rrule(until)

    case Timex.compare(new_event.dtstart, until) do
     -1 -> [new_event] ++ add_recurring_events_until(new_event, until)
      0 -> [new_event]
      1 -> []
    end
  end

  defp add_recurring_events_until(event, until, end_datetime) do
    case Timex.compare(until, end_datetime) do
      -1 -> add_recurring_events_until(event, until)
      _ -> add_recurring_events_until(event, end_datetime)
    end
  end

  defp add_recurring_events_count(event, count, end_datetime) do
    new_event = event |> shift |> adjust_rrule(count)

    if count > 1 && Timex.compare(new_event.dtstart, end_datetime) < 1 do
      [new_event] ++ add_recurring_events_count(new_event, count - 1, end_datetime)
    else
      [new_event]
    end
  end

  defp adjust_rrule(event, count) when is_integer(count) do
    rrule = event.rrule |> Map.put(:count, count)

    event |> Map.put(:rrule, rrule)
  end

  defp adjust_rrule(event, until) do
    rrule = event.rrule |> Map.put(:until, until)

    event |> Map.put(:rrule, rrule)
  end

  defp shift(%Event{dtend: nil} = event) do
    event
    |> Map.put(:dtstart, Timex.shift(event.dtstart, shift_options(event.rrule)))
  end

  defp shift(%Event{} = event) do
    options = shift_options(event.rrule)

    event
    |> Map.put(:dtstart, Timex.shift(event.dtstart, options))
    |> Map.put(:dtend, Timex.shift(event.dtend, options))
  end

  defp shift_options(%RRULE{frequency: :secondly} = rrule), do: [seconds: rrule.interval || 1]
  defp shift_options(%RRULE{frequency: :minutely} = rrule), do: [minutes: rrule.interval || 1]
  defp shift_options(%RRULE{frequency: :hourly} = rrule), do: [hours: rrule.interval || 1]
  defp shift_options(%RRULE{frequency: :daily} = rrule), do: [days: rrule.interval || 1]
  defp shift_options(%RRULE{frequency: :weekly} = rrule), do: [weeks: rrule.interval || 1]
  defp shift_options(%RRULE{frequency: :monthly} = rrule), do: [months: rrule.interval || 1]

  defp complex?(%RRULE{} = rrule) do
    rrule
    |> Map.to_list
    |> Enum.filter(fn {_, v} -> v && (v != [] && v != ICalendar.RRULE) end)
    |> Enum.filter(fn {k, _} -> Atom.to_string(k) =~ "by_" end)
    |> Enum.any?
  end

  # starting with common cases/low hanging fruit
  # there are other rrule combinations that we are skipping for now
  # get first iteration of occurrences as separate events
  # add simplified rrule to them
  # then call occurrences(event_list)
  defp simplify_to_base_events(%{rrule: %{frequency: :monthly, by_month_day: days} = rrule} = event) when days != [] do
    if has_negative?(days), do: raise "negative values for :by_month_day not supported yet"

    rrule = simplify(rrule, :by_month_day, days)

    # if passed event has different day number than in days, it's additional single occurrence
    # erase it's rrule and keep it in events
    if !Enum.member?(days, event.dtstart.day) do
      event = event |> Map.put(:rrule, nil)

      [event] ++ events_for_monthly_day_numbers(days, event, rrule)
    else
      # otherwise only add simplified rrule events for day number different than event
      events_for_monthly_day_numbers(days, event, rrule)
    end
  end

  defp simplify_to_base_events(%{rrule: %{frequency: :weekly, by_day: days} = rrule} = event) when days != [] do
    # ICalendar.RRULE doesn't handle number prefixed days for now, but it may in future
    # if number_prefixes?(days), do: raise "number prefixes for :by_days not supported yet"

    rrule = simplify(rrule, :by_day, days)

    # if passed event has different day than in days, it's additional single occurrence
    # erase it's rrule and keep it in events
    if !Enum.member?(days, day_key(event)) do
      event = event |> Map.put(:rrule, nil)

      [event] ++ events_for_weekly(days, event, rrule)
    else
      # otherwise only add simplified rrule events for days different than event
      events_for_weekly(days, event, rrule)
    end
  end

  defp simplify_to_base_events(%{rrule: rrule}), do: raise "#{rrule} complex rule pattern not supported yet"

  # create an event for each day number in days with simplified rrule
  defp events_for_monthly_day_numbers(days, base_event, target_rrule) do
    duration_in_seconds = duration_in_seconds(base_event)

    days
    |> Enum.map(fn day_number ->
      dtstart = %{base_event.dtstart | day: day_number}
      dtend = Timex.shift(dtstart, seconds: duration_in_seconds)

      %{base_event | rrule: target_rrule, dtstart: dtstart, dtend: dtend}
    end)
  end

  # create an event for each day in days with simplified rrule
  defp events_for_weekly(days, base_event, target_rrule) do
    duration_in_seconds = duration_in_seconds(base_event)
    base_day_key = day_key(base_event)

    days
    |> Enum.map(fn day_key ->
      if day_key == base_day_key do
        %{base_event | rrule: target_rrule, dtstart: base_event.dtstart, dtend: base_event.dtend}
      else
        next_date = to_next_date(day_key, base_event.dtstart)
        dtstart =
          base_event.dtstart
          |> Map.put(:year, next_date.year)
          |> Map.put(:month, next_date.month)
          |> Map.put(:day, next_date.day)
        dtend = Timex.shift(dtstart, seconds: duration_in_seconds)

        %{base_event | rrule: target_rrule, dtstart: dtstart, dtend: dtend}
      end
    end)
  end

  defp has_negative?(days) do
    days
    |> Enum.filter(fn day -> day < 0 end)
    |> Enum.any?
  end

  defp simplify(rrule, remove_key, values) do
    rrule = rrule |> Map.put(remove_key, [])

    if rrule.count do
      # fairly naive, see how it fairs in practice
      %{rrule | count: rrule.count / Enum.count(values) - 1}
    else
      rrule
    end
  end

  defp day_key(event) do
    {:ok, day_name} = Timex.format(event.dtstart, "%A", :strftime)
    day_name |> String.downcase |> String.to_atom
  end

  defp duration_in_seconds(event) do
    Timex.diff(event.dtend, event.dtstart, :seconds)
  end

  defp to_date_erl(datetime) do
    datetime
    |> DateTime.to_date
    |> Date.to_erl
  end

  defp to_next_date(day_key, datetime) do
    {:ok, next_date} =
      day_key
      |> find_weekday_on_or_following(to_date_erl(datetime))
      |> Date.from_erl

    next_date
  end

  # cribbed from https://github.com/alxndr/exercism/blob/0e29dbe6947dd9c5cea9b5c21f78951249fb1fe5/elixir/meetup/meetup.exs
  defp find_weekday_on_or_following(weekday, date_tuple) when not is_integer(weekday) do
    find_weekday_on_or_following weekday_to_int(weekday), date_tuple
  end

  defp find_weekday_on_or_following(weekday_int, date_tuple) do
    if weekday_int == :calendar.day_of_the_week(date_tuple) do
      date_tuple
    else
      {:ok, date} = Date.from_erl(date_tuple)
      new_date_tuple =
        date
        |> Timex.shift(days: 1)
        |> Date.to_erl

      find_weekday_on_or_following(weekday_int, new_date_tuple)
    end
  end

  defp weekday_to_int(:monday), do: 1
  defp weekday_to_int(:tuesday), do: 2
  defp weekday_to_int(:wednesday), do: 3
  defp weekday_to_int(:thursday), do: 4
  defp weekday_to_int(:friday), do: 5
  defp weekday_to_int(:saturday), do: 6
  defp weekday_to_int(:sunday), do: 7

  defp build_occurrences(event, rrule) do
    events = if complex?(rrule) do
      event |> simplify_to_base_events |> occurrences
    else
      occurrences([event])
    end

    events |> Enum.sort_by(fn e -> DateTime.to_unix(e.dtstart) end)
  end
end
