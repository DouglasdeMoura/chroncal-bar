function pad2(value) {
  return value < 10 ? "0" + value : String(value);
}

function parseDate(value) {
  var date = new Date(value);
  return isNaN(date.getTime()) ? null : date;
}

// All-day events are floating dates: Chroncal stores them as
// "YYYY-MM-DDT00:00:00Z", but the date part is the calendar day everywhere.
// Parsing that as a UTC instant shifts the day west of Greenwich.
function localDateFromKey(value) {
  var match = /^(\d{4})-(\d{2})-(\d{2})/.exec(String(value || ""));
  if (!match) return null;
  return new Date(Number(match[1]), Number(match[2]) - 1, Number(match[3]));
}

function eventStartDate(event) {
  if (!event) return null;
  if (event.all_day === true) return localDateFromKey(event.start_time) || parseDate(event.start_time);
  return parseDate(event.start_time);
}

function eventEndDate(event) {
  if (!event) return null;
  if (event.all_day === true) {
    var end = localDateFromKey(event.end_time);
    var start = eventStartDate(event);
    if (end && (!start || end > start)) return end;
    return start ? new Date(start.getFullYear(), start.getMonth(), start.getDate() + 1) : null;
  }
  return parseDate(event.end_time) || parseDate(event.start_time);
}

function eventHasEnded(event, now) {
  var end = eventEndDate(event);
  return end !== null && end.getTime() <= now.getTime();
}

function eventIsOngoing(event, now) {
  var start = eventStartDate(event);
  var end = eventEndDate(event);
  return start !== null && end !== null && start.getTime() <= now.getTime() && end.getTime() > now.getTime();
}

function activeEvents(events, nowValue) {
  var now = parseDate(nowValue) || new Date();
  return (events || []).filter(function(event) { return !eventHasEnded(event, now); });
}

function dateKey(date) {
  return date.getFullYear() + "-" + pad2(date.getMonth() + 1) + "-" + pad2(date.getDate());
}

function startOfLocalDay(date) {
  return new Date(date.getFullYear(), date.getMonth(), date.getDate());
}

function dayDifference(left, right) {
  return Math.round((startOfLocalDay(left).getTime() - startOfLocalDay(right).getTime()) / 86400000);
}

function dayLabel(date, now) {
  var difference = dayDifference(date, now);
  if (difference === 0) return "Today";
  if (difference === 1) return "Tomorrow";
  if (difference === -1) return "Yesterday";

  var weekdays = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"];
  if (difference > -7 && difference < 7) return weekdays[date.getDay()];

  var months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];
  return weekdays[date.getDay()] + ", " + months[date.getMonth()] + " " + date.getDate();
}

function eventSort(left, right) {
  if (left.all_day !== right.all_day) return left.all_day ? -1 : 1;
  var leftStart = eventStartDate(left);
  var rightStart = eventStartDate(right);
  var difference = (leftStart ? leftStart.getTime() : 0) - (rightStart ? rightStart.getTime() : 0);
  if (difference !== 0) return difference;
  return String(left.title || "").localeCompare(String(right.title || ""));
}

function shortDateLabel(date) {
  var weekdays = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"];
  var months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];
  return weekdays[date.getDay()] + ", " + months[date.getMonth()] + " " + date.getDate();
}

// Day an event is listed under: its start day, or today when it began
// earlier and is still running (multi-day and overnight events).
function eventAgendaDayKey(event, now) {
  var start = eventStartDate(event);
  if (!start) return "";
  var key = dateKey(start);
  var todayKey = dateKey(now);
  if (key < todayKey && eventIsOngoing(event, now)) return todayKey;
  return key;
}

function groupEvents(events, nowValue, options) {
  var now = parseDate(nowValue) || new Date();
  var todayKey = dateKey(now);
  var groups = [];
  var byKey = {};

  function groupFor(key) {
    var group = byKey[key];
    if (!group) {
      var date = localDateFromKey(key);
      group = { key: key, label: dayLabel(date, now), detail: shortDateLabel(date), today: key === todayKey, events: [] };
      byKey[key] = group;
      groups.push(group);
    }
    return group;
  }

  if (options && options.includeToday === true) groupFor(todayKey);
  var source = events || [];
  for (var index = 0; index < source.length; index++) {
    var key = eventAgendaDayKey(source[index], now);
    if (key !== "") groupFor(key).events.push(source[index]);
  }
  groups.sort(function(left, right) { return left.key < right.key ? -1 : (left.key > right.key ? 1 : 0); });
  for (var g = 0; g < groups.length; g++) groups[g].events.sort(eventSort);
  return groups;
}

// Flattened agenda order, matching what the panel renders top to bottom.
function agendaOrder(groups) {
  var ordered = [];
  for (var g = 0; g < (groups || []).length; g++)
    for (var e = 0; e < groups[g].events.length; e++) ordered.push(groups[g].events[e]);
  return ordered;
}

function formatTime(value) {
  var date = parseDate(value);
  if (!date) return "";
  return pad2(date.getHours()) + ":" + pad2(date.getMinutes());
}

function formatEventRange(event) {
  if (!event) return "";
  if (event.all_day === true) return "All day";
  return formatTime(event.start_time) + "–" + formatTime(event.end_time);
}

function monthName(date) {
  return ["January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"][date.getMonth()];
}

function formatInspectorDate(date, now) {
  var weekdays = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"];
  var datePart = monthName(date) + " " + date.getDate();
  if (date.getFullYear() !== now.getFullYear()) datePart += ", " + date.getFullYear();
  var difference = dayDifference(date, now);
  if (difference === 0) return "Today, " + datePart;
  if (difference === 1) return "Tomorrow, " + datePart;
  if (difference === -1) return "Yesterday, " + datePart;
  return weekdays[date.getDay()] + ", " + datePart;
}

function eventInclusiveEnd(event) {
  var end = eventEndDate(event);
  if (!end) return eventStartDate(event);
  // Ends are exclusive: a 23:00–00:00 meeting stays on its start day.
  var start = eventStartDate(event);
  if (start && end > start) return new Date(end.getTime() - 1);
  return end;
}

function formatEventDate(event, nowValue) {
  var start = eventStartDate(event);
  if (!start) return "";
  var now = parseDate(nowValue) || new Date();
  var end = eventInclusiveEnd(event) || start;
  var startLabel = formatInspectorDate(start, now);
  if (dateKey(start) === dateKey(end)) return startLabel;
  return startLabel + " – " + formatInspectorDate(end, now);
}

function eventProgress(event, nowValue) {
  if (!event || event.all_day === true) return 0;
  var start = eventStartDate(event);
  var end = eventEndDate(event);
  var now = parseDate(nowValue) || new Date();
  if (!start || !end || now <= start || now >= end || end <= start) return 0;
  return Math.max(0, Math.min(1, (now.getTime() - start.getTime()) / (end.getTime() - start.getTime())));
}

function clampSelection(index, length) {
  if (length <= 0) return -1;
  return Math.max(0, Math.min(length - 1, index));
}

function firstEventIndexForDate(events, nowValue) {
  var now = parseDate(nowValue) || new Date();
  var today = dateKey(now);
  for (var index = 0; index < (events || []).length; index += 1) {
    if (eventAgendaDayKey(events[index], now) === today) return index;
  }
  return -1;
}

function eventDateKey(event, nowValue) {
  if (nowValue !== undefined) return eventAgendaDayKey(event, parseDate(nowValue) || new Date());
  var start = eventStartDate(event);
  return start ? dateKey(start) : "";
}

function firstEventIndexForDay(events, dayKey, nowValue) {
  var key = String(dayKey || "");
  if (key === "") return -1;
  for (var index = 0; index < (events || []).length; index += 1) {
    if (eventDateKey(events[index], nowValue) === key) return index;
  }
  return -1;
}

function adjacentDayFirstEventIndex(events, currentIndex, direction, nowValue) {
  var list = events || [];
  if (list.length === 0 || direction === 0) return -1;
  var current = currentIndex >= 0 && currentIndex < list.length ? list[currentIndex] : null;
  var currentKey = eventDateKey(current, nowValue);
  var targetKey = "";
  for (var index = 0; index < list.length; index += 1) {
    var key = eventDateKey(list[index], nowValue);
    if (key === "") continue;
    if (direction > 0) {
      if ((currentKey === "" || key > currentKey) && (targetKey === "" || key < targetKey)) targetKey = key;
    } else if (currentKey !== "" && key < currentKey && (targetKey === "" || key > targetKey)) {
      targetKey = key;
    }
  }
  return firstEventIndexForDay(list, targetKey, nowValue);
}

function eventKey(event) {
  if (!event) return "";
  var identity = String(event.uid || event.id || "");
  var occurrence = String(event.recurrence_id || event.start_time || "");
  return identity + "|" + occurrence;
}

function escapeHtml(value) {
  return String(value === undefined || value === null ? "" : value)
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;");
}

function htmlColor(value) {
  if (value && typeof value === "object" && isFinite(value.r) && isFinite(value.g) && isFinite(value.b)) {
    function channel(n) {
      var v = Math.round(Number(n) * 255);
      if (v < 0) v = 0;
      if (v > 255) v = 255;
      var hex = v.toString(16);
      return hex.length === 1 ? "0" + hex : hex;
    }
    return "#" + channel(value.r) + channel(value.g) + channel(value.b);
  }
  var text = String(value || "").trim();
  var argb = text.match(/^#([0-9A-Fa-f]{2})([0-9A-Fa-f]{6})$/);
  if (argb) return "#" + argb[2];
  var hex = text.match(/^#([0-9A-Fa-f]{6})$/);
  if (hex) return "#" + hex[1];
  var shortHex = text.match(/^#([0-9A-Fa-f]{3})$/);
  if (!shortHex) return "";
  var digits = shortHex[1];
  return "#" + digits.charAt(0) + digits.charAt(0) + digits.charAt(1) + digits.charAt(1) + digits.charAt(2) + digits.charAt(2);
}

function richText(value) {
  return "<span>" + value + "</span>";
}

function truncate(value, maximum) {
  var text = String(value || "");
  if (maximum <= 3 || text.length <= maximum) return text;
  return text.slice(0, maximum - 3) + "...";
}

function durationLabel(seconds) {
  var minutes = Math.max(0, Math.ceil(seconds / 60));
  if (minutes < 60) return minutes + "m";
  var hours = Math.floor(minutes / 60);
  var remainder = minutes % 60;
  return remainder === 0 ? hours + "h" : hours + "h " + remainder + "m";
}

function relativeDayLabel(date, now) {
  if (dateKey(date) === dateKey(now)) return "";
  var day = new Date(date.getFullYear(), date.getMonth(), date.getDate());
  var today = new Date(now.getFullYear(), now.getMonth(), now.getDate());
  var delta = Math.round((day.getTime() - today.getTime()) / 86400000);
  if (delta === 1) return "Tomorrow";
  return ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"][date.getDay()];
}

function eventLeadLabel(event, now, relativeLeadMinutes) {
  var start = eventStartDate(event);
  var end = eventEndDate(event);
  if (!start || !end) return "";
  if (event.all_day === true) {
    var allDayLabel = relativeDayLabel(start, now);
    return start.getTime() <= now.getTime() || allDayLabel === "" ? "All day" : allDayLabel;
  }
  var untilStart = (start.getTime() - now.getTime()) / 1000;
  if (untilStart > 0) {
    var leadSeconds = Math.max(0, Number(relativeLeadMinutes === undefined ? 10 : relativeLeadMinutes)) * 60;
    if (untilStart <= leadSeconds) return "in " + durationLabel(untilStart);
    var dayLabel = relativeDayLabel(start, now);
    if (dayLabel !== "") return dayLabel + " " + formatTime(event.start_time);
    return formatTime(event.start_time);
  }
  if ((now.getTime() - start.getTime()) < 60000) return "Now";
  return durationLabel((end.getTime() - now.getTime()) / 1000) + " left";
}

// Short live status for agenda rows: "Now · 12m left", "in 25m".
function eventRowStatus(event, nowValue) {
  if (!event || event.all_day === true) return "";
  var now = parseDate(nowValue) || new Date();
  var start = eventStartDate(event);
  var end = eventEndDate(event);
  if (!start || !end || end <= now) return "";
  if (start <= now) return durationLabel((end.getTime() - now.getTime()) / 1000) + " left";
  var until = (start.getTime() - now.getTime()) / 1000;
  return until <= 3600 ? "in " + durationLabel(until) : "";
}

function eventRowSubtitle(event) {
  var parts = [formatEventRange(event)];
  if (event && event.location && firstUrlInText(event.location) === "") parts.push(String(event.location));
  else if (event && event.calendar_name) parts.push(String(event.calendar_name));
  if (awaitingResponse(event)) parts.push("Invited");
  else if (userRsvpStatus(event) === "TENTATIVE") parts.push("Maybe");
  else if (isDeclined(event)) parts.push("Declined");
  return parts.join("  ·  ");
}

function calendarColor(event) {
  return htmlColor(event.calendar_color || "#888888");
}

function tooltipLine(event) {
  var when = event.all_day === true ? "All day" : formatEventRange(event);
  return "■  " + when + " · " + (event.title || "Untitled");
}

function arrayValues(value) {
  if (!value || typeof value.length !== "number" || typeof value === "string") return [];
  var values = [];
  for (var i = 0; i < value.length; i++) values.push(value[i]);
  return values;
}

function optionEnabled(options, key, fallback) {
  if (!options || options[key] === undefined || options[key] === null) return fallback;
  if (options[key] === false) return false;
  return String(options[key]).toLowerCase() !== "off";
}

function calendarSelectionCustomized(settings) {
  if (!settings) return false;
  if (settings.calendarSelectionCustomized !== undefined && settings.calendarSelectionCustomized !== null)
    return settings.calendarSelectionCustomized === true || String(settings.calendarSelectionCustomized).toLowerCase() === "true";
  return arrayValues(settings.includedCalendarIds).length > 0;
}

function selectedCalendarIds(calendars, settings) {
  if (calendarSelectionCustomized(settings))
    return arrayValues(settings && settings.includedCalendarIds).map(function(value) { return String(value); });
  return (calendars || []).map(function(calendar) { return String(calendar.id); });
}

function filterEvents(events, options) {
  var source = events || [];
  var included = arrayValues(options && options.includedCalendarIds).map(function(value) { return String(value); });
  var selectionCustomized = calendarSelectionCustomized(options);
  var showAllDay = optionEnabled(options, "showAllDay", true);
  var showWithoutParticipants = optionEnabled(options, "showEventsWithoutParticipants", true);
  var showWithoutLocation = optionEnabled(options, "showEventsWithoutLocation", true);
  var showDeclined = optionEnabled(options, "showDeclinedEvents", true);

  return source.filter(function(event) {
    if (!showDeclined && isDeclined(event)) return false;
    if (selectionCustomized && included.indexOf(String(event.calendar_id)) === -1) return false;
    if (!showAllDay && event.all_day === true) return false;
    if (!showWithoutParticipants && (!event.attendees || event.attendees.length === 0)) return false;
    if (!showWithoutLocation && !event.location && eventConferenceUrl(event) === "") return false;
    return true;
  });
}

function searchEvents(events, query) {
  var source = events || [];
  var needle = String(query || "").trim().toLocaleLowerCase();
  if (needle === "") return source.slice();
  return source.filter(function(event) {
    var attendees = event && event.attendees ? event.attendees : [];
    var participantText = attendees.map(function(attendee) {
      return String((attendee && attendee.name) || "") + " " + String((attendee && attendee.email) || "");
    }).join(" ");
    var haystack = [
      event && event.title,
      event && event.description,
      event && event.location,
      event && event.calendar_name,
      participantText
    ].map(function(value) { return String(value || "").toLocaleLowerCase(); }).join(" ");
    return haystack.indexOf(needle) !== -1;
  });
}

function filterAgenda(agenda, options) {
  if (!agenda) return { status: "unavailable", events: [], next: null };
  var filtered = {};
  for (var key in agenda) filtered[key] = agenda[key];
  filtered.events = filterEvents(agenda.events || [], options);
  filtered.next = filtered.events.length > 0 ? filtered.events[0] : null;
  return filtered;
}

function calendarOptions(calendars) {
  return (calendars || []).map(function(calendar) {
    return { value: String(calendar.id), label: String(calendar.name || "Calendar"), description: "" };
  }).sort(function(a, b) { return a.label.localeCompare(b.label); });
}

function calendarNameOptions(calendars) {
  var seen = {};
  return (calendars || []).filter(function(calendar) {
    var name = String(calendar.name || "");
    if (name === "" || seen[name] || calendar.read_only === true) return false;
    seen[name] = true;
    return true;
  }).map(function(calendar) {
    return { value: String(calendar.name), label: String(calendar.name) };
  }).sort(function(a, b) { return a.label.localeCompare(b.label); });
}

function eventSegment(event, now, relativeLeadMinutes, titleLimit, showTime, showTitle) {
  var parts = [];
  if (showTime) parts.push(eventLeadLabel(event, now, relativeLeadMinutes));
  if (showTitle) parts.push(truncate(event.title, titleLimit));
  return { color: calendarColor(event), text: parts.join(" · ") };
}

function segmentsText(segments) {
  return segments.map(function(segment) {
    return (segment.color !== "" ? "■ " : "") + segment.text;
  }).join(" | ");
}

function segmentsHtml(segments) {
  return segments.map(function(segment) {
    var square = segment.color !== "" ? '<font color="' + segment.color + '">■</font> ' : "";
    return square + escapeHtml(segment.text);
  }).join(" | ");
}

// Picks what the bar shows, Notion Calendar style: timed meetings win over
// all-day events, declined invitations never show, and an ongoing meeting
// hands the bar over to the next one once it is inside the countdown window.
function barAnchor(events, now, options) {
  var opts = options || {};
  var leadMinutes = Number(opts.relativeLeadMinutes === undefined ? 10 : opts.relativeLeadMinutes);
  var horizonHours = Number(opts.barHorizonHours || 0);
  var horizonEnd = horizonHours > 0 ? now.getTime() + horizonHours * 3600000 : Infinity;
  var timed = [];
  var allDay = [];
  (events || []).forEach(function(event) {
    if (isDeclined(event) || eventHasEnded(event, now)) return;
    var start = eventStartDate(event);
    if (!start || start.getTime() > horizonEnd) return;
    if (event.all_day === true) allDay.push(event);
    else timed.push(event);
  });
  timed.sort(eventSort);
  allDay.sort(eventSort);
  var ongoing = timed.filter(function(event) { return eventIsOngoing(event, now); });
  var upcoming = timed.filter(function(event) { return !eventIsOngoing(event, now); });
  var soon = upcoming.length > 0 && (eventStartDate(upcoming[0]).getTime() - now.getTime()) <= Math.max(1, leadMinutes) * 60000;
  if (soon) return { anchor: upcoming[0], timed: timed };
  if (ongoing.length > 0) return { anchor: ongoing[0], timed: timed };
  var todayKey = dateKey(now);
  var allDayToday = allDay.filter(function(event) { return eventIsOngoing(event, now); });
  var nextTimed = upcoming.length > 0 ? upcoming[0] : null;
  if (nextTimed && dateKey(eventStartDate(nextTimed)) === todayKey) return { anchor: nextTimed, timed: timed };
  if (allDayToday.length > 0) return { anchor: allDayToday[0], timed: [] };
  if (nextTimed) return { anchor: nextTimed, timed: timed };
  if (allDay.length > 0) return { anchor: allDay[0], timed: [] };
  return { anchor: null, timed: [] };
}

function barPresentation(agenda, maximumTitleLength, displayOptions) {
  if (!agenda || agenda.status !== "ok") {
    return { text: "", html: "", className: "unavailable", tooltip: "chroncal unavailable", event: null };
  }

  var now = parseDate(displayOptions && displayOptions.now) || parseDate(agenda.generated_at) || new Date();
  var events = activeEvents(agenda.events || [], now.toISOString());
  var tooltip = events.length === 0 ? "No upcoming events" : events.map(tooltipLine).join("\n");
  var chosen = barAnchor(events, now, displayOptions);
  var anchor = chosen.anchor;
  if (!anchor) return { text: "", html: "", className: "empty", tooltip: tooltip, event: null };

  function present(segments, more, className) {
    var hasText = segments.some(function(segment) { return segment.text !== ""; });
    return {
      text: hasText ? " " + segmentsText(segments) + more + " " : "",
      html: hasText ? " " + segmentsHtml(segments) + more + " " : "",
      className: className,
      tooltip: tooltip,
      event: anchor
    };
  }

  var titleLimit = maximumTitleLength || 42;
  var showTime = optionEnabled(displayOptions, "showTime", true);
  var showTitle = optionEnabled(displayOptions, "showTitle", true);
  var relativeLeadMinutes = Number(displayOptions && displayOptions.relativeLeadMinutes !== undefined ? displayOptions.relativeLeadMinutes : 10);
  if (anchor.all_day === true)
    return present([eventSegment(anchor, now, relativeLeadMinutes, titleLimit, showTime, showTitle)], "", "all-day");

  var anchorStart = eventStartDate(anchor);
  var anchorEnd = eventEndDate(anchor);
  var className = eventIsOngoing(anchor, now) ? "in-progress" : "upcoming";
  var cluster = chosen.timed.filter(function(event) {
    var start = eventStartDate(event);
    var end = eventEndDate(event);
    if (!start || !end || !(start < anchorEnd && anchorStart < end)) return false;
    // An upcoming anchor only groups meetings that start with it.
    return className === "in-progress" ? eventIsOngoing(event, now) : start.getTime() === anchorStart.getTime();
  });
  if (cluster.length <= 1)
    return present([eventSegment(anchor, now, relativeLeadMinutes, titleLimit, showTime, showTitle)], "", className);

  var segments = cluster.slice(0, 3).map(function(event) {
    return eventSegment(event, now, relativeLeadMinutes, 18, showTime, showTitle);
  });
  var more = cluster.length > 3 ? " +" + (cluster.length - 3) : "";
  return present(segments, more, [className, "overlap"]);
}

function dateInputValue(value, allDay) {
  if (allDay && String(value || "").length >= 10) return String(value).slice(0, 10);
  var date = parseDate(value);
  if (!date) return "";
  return formatDateInput(date);
}

function parseDateInput(value) {
  var match = /^(\d{4})-(\d{2})-(\d{2})$/.exec(String(value || ""));
  if (!match) return null;
  var year = Number(match[1]);
  var month = Number(match[2]) - 1;
  var day = Number(match[3]);
  var date = new Date(year, month, day);
  if (date.getFullYear() !== year || date.getMonth() !== month || date.getDate() !== day) return null;
  return date;
}

function formatDateInput(date) {
  if (!date || isNaN(date.getTime())) return "";
  return date.getFullYear() + "-" + pad2(date.getMonth() + 1) + "-" + pad2(date.getDate());
}

function stepMonth(year, month, delta) {
  var target = new Date(Number(year), Number(month) + Number(delta), 1);
  return { year: target.getFullYear(), month: target.getMonth() };
}

function shiftDateInput(value, days) {
  var date = parseDateInput(value);
  if (!date) return "";
  date.setDate(date.getDate() + Number(days));
  return formatDateInput(date);
}

function weekdayOrder(weekStart) {
  var start = ((Number(weekStart) % 7) + 7) % 7;
  var days = [];
  for (var index = 0; index < 7; index += 1) days.push((start + index) % 7);
  return days;
}

function monthGrid(year, month, weekStart, todayKey, selectedKey) {
  var start = ((Number(weekStart) % 7) + 7) % 7;
  var leading = (new Date(year, month, 1).getDay() - start + 7) % 7;
  var cursor = new Date(year, month, 1 - leading);
  var weeks = [];
  for (var week = 0; week < 6; week += 1) {
    var days = [];
    for (var index = 0; index < 7; index += 1) {
      var key = formatDateInput(cursor);
      days.push({
        key: key,
        day: cursor.getDate(),
        inMonth: cursor.getMonth() === month && cursor.getFullYear() === year,
        today: key === String(todayKey || ""),
        selected: key === String(selectedKey || "")
      });
      cursor.setDate(cursor.getDate() + 1);
    }
    weeks.push(days);
  }
  return weeks;
}

function timeInputValue(value) {
  var date = parseDate(value);
  return date ? pad2(date.getHours()) + ":" + pad2(date.getMinutes()) : "";
}

function durationInputValue(event) {
  var start = parseDate(event && event.start_time);
  var end = parseDate(event && event.end_time);
  if (!start || !end || end <= start) return "1h";
  var minutes = Math.max(1, Math.round((end.getTime() - start.getTime()) / 60000));
  var hours = Math.floor(minutes / 60);
  var remainder = minutes % 60;
  if (hours === 0) return remainder + "m";
  return hours + "h" + (remainder > 0 ? remainder + "m" : "");
}

function eventEditorValues(event, nowValue) {
  if (event) {
    return {
      title: String(event.title || ""),
      date: dateInputValue(event.start_time, event.all_day === true),
      time: event.all_day === true ? "" : timeInputValue(event.start_time),
      duration: event.all_day === true ? "" : durationInputValue(event),
      allDay: event.all_day === true,
      calendar: String(event.calendar_name || ""),
      location: String(event.location || ""),
      description: splitVideoLine(event.description).text,
      video: splitVideoLine(event.description).url,
      recurrence: parseRecurrenceRule(event.recurrence_rule, dateInputValue(event.start_time, event.all_day === true))
    };
  }
  var nextHour = parseDate(nowValue) || new Date();
  nextHour = new Date(nextHour.getTime());
  nextHour.setMinutes(0, 0, 0);
  nextHour.setHours(nextHour.getHours() + 1);
  return {
    title: "",
    date: dateInputValue(nextHour, false),
    time: timeInputValue(nextHour),
    duration: "1h",
    allDay: false,
    calendar: "",
    location: "",
    description: "",
    video: "",
    recurrence: defaultRecurrenceForm(dateInputValue(nextHour, false))
  };
}

function validateEventForm(values) {
  var form = values || {};
  var errors = [];
  if (String(form.title || "").trim() === "") errors.push("Event title is required");
  if (!/^\d{4}-\d{2}-\d{2}$/.test(String(form.date || ""))) errors.push("Date must use YYYY-MM-DD");
  if (form.allDay !== true && !/^([01]\d|2[0-3]):[0-5]\d$/.test(String(form.time || ""))) errors.push("Time must use HH:MM");
  if (form.allDay !== true && !/^(?=.+)(?:\d+h)?(?:\d+m)?$/.test(String(form.duration || ""))) errors.push("Duration must look like 30m or 1h30m");
  if (!isVideoUrl(form.video)) errors.push("Video call must be an https:// link");
  errors = errors.concat(validateRecurrenceForm(form.recurrence, form.date));
  return errors;
}

var WEEKDAY_RRULE = ["SU", "MO", "TU", "WE", "TH", "FR", "SA"];
var REPEAT_PRESET_RULES = {
  none: "",
  daily: "FREQ=DAILY",
  weekly: "FREQ=WEEKLY",
  biweekly: "FREQ=WEEKLY;INTERVAL=2",
  monthly: "FREQ=MONTHLY",
  yearly: "FREQ=YEARLY",
  weekdays: "FREQ=WEEKLY;BYDAY=MO,TU,WE,TH,FR"
};

function repeatPresetOptions() {
  return [
    { value: "none", label: "None" },
    { value: "daily", label: "Every day" },
    { value: "weekly", label: "Every week" },
    { value: "biweekly", label: "Every 2 weeks" },
    { value: "monthly", label: "Every month" },
    { value: "yearly", label: "Every year" },
    { value: "weekdays", label: "Weekdays" },
    { value: "custom", label: "Custom..." }
  ];
}

function frequencyOptions() {
  return [
    { value: "DAILY", label: "Day" },
    { value: "WEEKLY", label: "Week" },
    { value: "MONTHLY", label: "Month" },
    { value: "YEARLY", label: "Year" }
  ];
}

function endsOptions() {
  return [
    { value: "never", label: "Never" },
    { value: "after", label: "After" },
    { value: "ondate", label: "On date" }
  ];
}

function emptyWeekDays() {
  return [false, false, false, false, false, false, false];
}

function addMonthsClamped(date, months) {
  var last = new Date(date.getFullYear(), date.getMonth() + months + 1, 0).getDate();
  return new Date(date.getFullYear(), date.getMonth() + months, Math.min(date.getDate(), last));
}

function defaultRecurrenceForm(startDateValue) {
  var date = parseDateInput(startDateValue) || new Date();
  var weekDays = emptyWeekDays();
  weekDays[date.getDay()] = true;
  return {
    preset: "none",
    interval: 1,
    freq: "WEEKLY",
    weekDays: weekDays,
    monthlyMode: "date",
    ends: "never",
    count: 1,
    until: formatDateInput(addMonthsClamped(date, 3))
  };
}

function cloneRecurrenceForm(form) {
  var source = form || defaultRecurrenceForm("");
  var next = {};
  for (var key in source) next[key] = source[key];
  next.weekDays = (source.weekDays || emptyWeekDays()).slice();
  return next;
}

function rruleParamMap(rule) {
  var map = {};
  var parts = String(rule || "").split(";");
  for (var i = 0; i < parts.length; i++) {
    var cut = parts[i].split("=");
    if (cut.length < 2) continue;
    map[String(cut[0] || "").toUpperCase().trim()] = cut.slice(1).join("=").trim();
  }
  return map;
}

function recurrenceBaseRule(rule) {
  var parts = String(rule || "").split(";");
  var kept = [];
  for (var i = 0; i < parts.length; i++) {
    var upper = parts[i].toUpperCase();
    if (upper.indexOf("COUNT=") === 0 || upper.indexOf("UNTIL=") === 0) continue;
    if (parts[i] !== "") kept.push(parts[i]);
  }
  return kept.join(";");
}

function formatRRuleUntil(value) {
  var date = parseDateInput(value);
  if (!date) return "";
  var end = new Date(date.getFullYear(), date.getMonth(), date.getDate(), 23, 59, 59, 0);
  return String(end.getUTCFullYear()) + pad2(end.getUTCMonth() + 1) + pad2(end.getUTCDate()) + "T" +
    pad2(end.getUTCHours()) + pad2(end.getUTCMinutes()) + pad2(end.getUTCSeconds()) + "Z";
}

function parseRRuleUntil(value) {
  var text = String(value || "");
  if (/^\d{8}T\d{6}Z$/.test(text)) {
    return parseDate(
      text.slice(0, 4) + "-" + text.slice(4, 6) + "-" + text.slice(6, 8) + "T" +
      text.slice(9, 11) + ":" + text.slice(11, 13) + ":" + text.slice(13, 15) + "Z"
    );
  }
  if (/^\d{8}$/.test(text)) {
    return parseDateInput(text.slice(0, 4) + "-" + text.slice(4, 6) + "-" + text.slice(6, 8));
  }
  return null;
}

function nthWeekdayOf(date) {
  return {
    nth: Math.floor((date.getDate() - 1) / 7) + 1,
    day: WEEKDAY_RRULE[date.getDay()]
  };
}

function nthWeekdayLabel(date) {
  var nth = nthWeekdayOf(date).nth;
  var ordinals = ["", "1st", "2nd", "3rd", "4th", "5th"];
  var ord = nth > 0 && nth < ordinals.length ? ordinals[nth] : "nth";
  var weekdays = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"];
  return ord + " " + weekdays[date.getDay()];
}

function monthlyOnOptions(startDateValue) {
  var date = parseDateInput(startDateValue) || new Date();
  return [
    { value: "date", label: "Day " + date.getDate() },
    { value: "nth", label: nthWeekdayLabel(date) }
  ];
}

function parseRecurrenceRule(rule, startDateValue) {
  var form = defaultRecurrenceForm(startDateValue);
  var text = String(rule || "").trim();
  if (text === "") return form;
  var parts = rruleParamMap(text);
  var freq = String(parts.FREQ || "").toUpperCase();
  if (freq === "DAILY" || freq === "WEEKLY" || freq === "MONTHLY" || freq === "YEARLY") form.freq = freq;
  var interval = Number(parts.INTERVAL || "1");
  if (interval >= 1) form.interval = interval;
  if (parts.COUNT) {
    form.ends = "after";
    form.count = Number(parts.COUNT) || 1;
  } else if (parts.UNTIL) {
    form.ends = "ondate";
    var untilDate = parseRRuleUntil(parts.UNTIL);
    if (untilDate) form.until = formatDateInput(untilDate);
  }
  if (parts.BYDAY) {
    var days = String(parts.BYDAY).split(",");
    var weekDays = emptyWeekDays();
    var sawNth = false;
    for (var i = 0; i < days.length; i++) {
      var code = String(days[i] || "").toUpperCase().trim();
      var dayPart = code.replace(/^[+-]?\d+/, "");
      if (dayPart !== code) sawNth = true;
      for (var w = 0; w < 7; w++) if (WEEKDAY_RRULE[w] === dayPart) weekDays[w] = true;
    }
    form.weekDays = weekDays;
    if (form.freq === "MONTHLY" && sawNth) form.monthlyMode = "nth";
  }
  var base = recurrenceBaseRule(text);
  var presets = ["daily", "weekly", "biweekly", "monthly", "yearly", "weekdays"];
  for (var p = 0; p < presets.length; p++) {
    if (base.toUpperCase() === REPEAT_PRESET_RULES[presets[p]].toUpperCase()) {
      form.preset = presets[p];
      return form;
    }
  }
  form.preset = "custom";
  return form;
}

function appendRecurrenceEnds(rule, form) {
  if (String(form.ends || "never") === "after") {
    var count = Number(form.count || 0);
    if (count >= 1) return rule + ";COUNT=" + String(Math.floor(count));
  }
  if (String(form.ends || "never") === "ondate") {
    var until = formatRRuleUntil(form.until);
    if (until !== "") return rule + ";UNTIL=" + until;
  }
  return rule;
}

function buildRecurrenceRule(form, startDateValue) {
  var rec = form || defaultRecurrenceForm(startDateValue);
  var preset = String(rec.preset || "none");
  if (preset === "none") return "";
  if (preset !== "custom") {
    var presetRule = REPEAT_PRESET_RULES[preset] || "";
    return presetRule === "" ? "" : appendRecurrenceEnds(presetRule, rec);
  }
  var freq = String(rec.freq || "WEEKLY").toUpperCase();
  if (freq !== "DAILY" && freq !== "WEEKLY" && freq !== "MONTHLY" && freq !== "YEARLY") freq = "WEEKLY";
  var rule = "FREQ=" + freq;
  var interval = Number(rec.interval || 1);
  if (interval > 1) rule += ";INTERVAL=" + String(Math.floor(interval));
  if (freq === "WEEKLY") {
    var days = [];
    var weekDays = rec.weekDays || [];
    for (var i = 0; i < 7; i++) if (weekDays[i]) days.push(WEEKDAY_RRULE[i]);
    if (days.length > 0) rule += ";BYDAY=" + days.join(",");
  } else if (freq === "MONTHLY" && rec.monthlyMode === "nth") {
    var start = parseDateInput(startDateValue);
    if (start) {
      var nth = nthWeekdayOf(start);
      rule += ";BYDAY=" + String(nth.nth) + nth.day;
    }
  }
  return appendRecurrenceEnds(rule, rec);
}

function applyRepeatPreset(form, nextPreset, startDateValue) {
  var current = cloneRecurrenceForm(form || defaultRecurrenceForm(startDateValue));
  var preset = String(nextPreset || "none");
  if (preset === "custom" && current.preset !== "custom") {
    var parsed = parseRecurrenceRule(buildRecurrenceRule(current, startDateValue), startDateValue);
    parsed.preset = "custom";
    return parsed;
  }
  current.preset = preset;
  return current;
}

function validateRecurrenceForm(form, startDateValue) {
  var rec = form || defaultRecurrenceForm(startDateValue);
  var errors = [];
  if (String(rec.preset || "none") === "none") return errors;
  if (String(rec.preset) === "custom") {
    if (!(Number(rec.interval) >= 1)) errors.push("Repeat interval must be at least 1");
  }
  if (String(rec.ends) === "after" && !(Number(rec.count) >= 1)) errors.push("Ends after count must be at least 1");
  if (String(rec.ends) === "ondate") {
    var until = parseDateInput(rec.until);
    var start = parseDateInput(startDateValue);
    if (!until) errors.push("End date must use YYYY-MM-DD");
    else if (start && until < start) errors.push("End date must be on or after the start date");
  }
  return errors;
}

function recurrenceRuleSummary(form, startDateValue) {
  var rec = form || defaultRecurrenceForm(startDateValue);
  var preset = String(rec.preset || "none");
  if (preset === "none") return "Does not repeat";
  if (preset !== "custom") {
    var options = repeatPresetOptions();
    for (var i = 0; i < options.length; i++) if (options[i].value === preset) return options[i].label;
  }
  var freqLabels = { DAILY: ["Daily", "day", "days"], WEEKLY: ["Weekly", "week", "weeks"], MONTHLY: ["Monthly", "month", "months"], YEARLY: ["Yearly", "year", "years"] };
  var freq = String(rec.freq || "WEEKLY").toUpperCase();
  var names = freqLabels[freq] || freqLabels.WEEKLY;
  var interval = Number(rec.interval || 1);
  var summary = interval === 1 ? names[0] : "Every " + String(Math.floor(interval)) + " " + names[2];
  if (freq === "WEEKLY") {
    var labels = [];
    var weekDays = rec.weekDays || [];
    var weekdayShort = ["Su", "Mo", "Tu", "We", "Th", "Fr", "Sa"];
    for (var d = 0; d < 7; d++) if (weekDays[d]) labels.push(weekdayShort[d]);
    if (labels.length > 0 && labels.length < 7) summary += " on " + labels.join(", ");
  }
  if (freq === "MONTHLY" && rec.monthlyMode === "nth") {
    var start = parseDateInput(startDateValue);
    if (start) summary += " on " + nthWeekdayLabel(start);
  }
  return summary;
}

// HH:MM edits are read in the local zone, so an event pinned to another
// IANA zone keeps its time unless that zone is the local one.
function canEditEventTime(event, localTimezone) {
  if (!event) return true;
  var zone = String(event.timezone || "");
  return zone === "" || (String(localTimezone || "") !== "" && zone === String(localTimezone));
}

function canEditRecurrence(event) {
  if (!event) return true;
  return String(event.recurrence_id || "") === "";
}

function presentValue(value) {
  return value !== undefined && value !== null && String(value) !== "";
}

function eventReference(event) {
  if (!event) return "";
  if (presentValue(event.id)) return String(event.id);
  if (presentValue(event.uid)) return String(event.uid);
  return "";
}

function isReadOnlyEvent(event) {
  return !!event && event.calendar_read_only === true;
}

function canEditEvent(event) {
  return eventReference(event) !== "" && !isReadOnlyEvent(event);
}

function isGeneratedRecurringEvent(event) {
  if (!event) return false;
  var recurring = String(event.recurrence_rule || "") !== "" || String(event.rdates || "") !== "";
  return recurring && String(event.recurrence_id || "") === "";
}

function canMutateEvent(event) {
  if (!canEditEvent(event)) return false;
  return !isGeneratedRecurringEvent(event);
}

function isRecurringEvent(event) {
  if (!event) return false;
  return isGeneratedRecurringEvent(event) || String(event.recurrence_id || "") !== "";
}

function canDeleteEvent(event) {
  return canEditEvent(event);
}

function eventSeriesReference(event) {
  if (event && presentValue(event.uid)) return String(event.uid);
  return eventReference(event);
}

function eventOccurrenceStamp(event) {
  if (event && presentValue(event.recurrence_id)) return String(event.recurrence_id);
  return String(event && event.start_time || "").trim();
}

function eventMutationTargetArgs(event) {
  if (event && event.recurrence_id && event.uid)
    return [String(event.uid), "--recurrence-id", String(event.recurrence_id)];
  return [eventReference(event)];
}

function seriesMasterLookupArgs(event) {
  if (!canEditEvent(event) || !isGeneratedRecurringEvent(event)) return [];
  return ["event", "get", eventReference(event), "--output", "json"];
}

function seriesEditorEvent(master, occurrence) {
  if (!isGeneratedRecurringEvent(master) || !isGeneratedRecurringEvent(occurrence)) return null;
  var idsComparable = presentValue(master.id) && presentValue(occurrence.id);
  var uidsComparable = presentValue(master.uid) && presentValue(occurrence.uid);
  if (idsComparable && String(master.id) !== String(occurrence.id)) return null;
  if (uidsComparable && String(master.uid) !== String(occurrence.uid)) return null;
  if (!idsComparable && !uidsComparable) return null;
  var editorEvent = {};
  for (var key in master) editorEvent[key] = master[key];
  var metadataFields = ["calendar_id", "calendar_name", "calendar_color", "calendar_owner_email"];
  for (var i = 0; i < metadataFields.length; i++) {
    var field = metadataFields[i];
    if (!presentValue(editorEvent[field]) && presentValue(occurrence[field])) editorEvent[field] = occurrence[field];
  }
  return editorEvent;
}

function pushOptionalFlag(args, flag, value) {
  var text = String(value || "").trim();
  if (text !== "") args.push(flag, text);
}

function eventMutationArgs(mode, event, values, options) {
  var errors = validateEventForm(values);
  var seriesEdit = mode === "edit" && options && options.series === true &&
    canEditEvent(event) && isGeneratedRecurringEvent(event);
  if (errors.length > 0 || (mode === "edit" && !canMutateEvent(event) && !seriesEdit)) return [];
  var form = values || {};
  var title = String(form.title || "").trim();
  var args;
  if (mode === "edit") {
    var original = eventEditorValues(event);
    if ((form.allDay === true) !== (original.allDay === true)) return [];
    var dateChanged = String(form.date) !== String(original.date);
    var timeChanged = String(form.time) !== String(original.time);
    var durationChanged = String(form.duration) !== String(original.duration);
    if (!canEditEventTime(event, options && options.localTimezone) && (dateChanged || timeChanged || durationChanged)) return [];
    args = ["event", "update"].concat(eventMutationTargetArgs(event));
    args.push("--title", title);
    if (dateChanged) args.push("--date", String(form.date));
    if (String(form.calendar || "") !== String(original.calendar || ""))
      pushOptionalFlag(args, "--calendar", form.calendar);
    if (form.allDay !== true) {
      if (timeChanged) args.push("--time", String(form.time));
      if (durationChanged) args.push("--duration", String(form.duration));
    }
    if (String(form.location || "") !== String(original.location || ""))
      args.push("--location", String(form.location || ""));
    var nextDescription = composeDescription(form.description, form.video);
    if (nextDescription !== composeDescription(original.description, original.video))
      args.push("--description", nextDescription);
    if (canEditRecurrence(event) && form.recurrence) {
      var nextRule = buildRecurrenceRule(form.recurrence, form.date);
      var storedRule = String(event.recurrence_rule || "");
      var canonicalStored = buildRecurrenceRule(parseRecurrenceRule(storedRule, form.date), form.date);
      if (nextRule !== storedRule && nextRule !== canonicalStored) args.push("--recurrence-rule", nextRule);
    }
    return args;
  }

  args = ["event", "add", "--date", String(form.date)];
  pushOptionalFlag(args, "--calendar", form.calendar);
  if (form.allDay !== true) args.push("--time", String(form.time), "--duration", String(form.duration));
  pushOptionalFlag(args, "--location", form.location);
  pushOptionalFlag(args, "--description", composeDescription(form.description, form.video));
  var createRule = buildRecurrenceRule(form.recurrence, form.date);
  if (createRule !== "") args.push("--recurrence-rule", createRule);
  args.push("--", title);
  return args;
}

function eventDeleteArgs(event, options) {
  var opts = options || {};
  if (!canEditEvent(event)) return [];
  var thisEvent = opts.thisEvent === true;
  var following = opts.following === true;
  var series = opts.series === true;
  if ((thisEvent ? 1 : 0) + (following ? 1 : 0) + (series ? 1 : 0) > 1) return [];
  if (series) {
    var seriesRef = eventSeriesReference(event);
    return seriesRef === "" ? [] : ["event", "delete", seriesRef, "--series", "--yes"];
  }
  if (thisEvent || following) {
    var stamp = eventOccurrenceStamp(event);
    var target = eventSeriesReference(event);
    if (target === "" || stamp === "") return [];
    if (following) return ["event", "delete", target, "--following", stamp, "--yes"];
    return ["event", "delete", target, "--recurrence-id", stamp, "--yes"];
  }
  if (!canMutateEvent(event)) return [];
  return ["event", "delete"].concat(eventMutationTargetArgs(event)).concat(["--yes"]);
}

function rsvpChoices() {
  return [
    { value: "ACCEPTED", label: "Yes" },
    { value: "TENTATIVE", label: "Maybe" },
    { value: "DECLINED", label: "No" }
  ];
}

function normalizeRsvpStatus(value) {
  var raw = String(value || "").trim().toUpperCase();
  if (raw === "ACCEPTED" || raw === "YES" || raw === "Y") return "ACCEPTED";
  if (raw === "DECLINED" || raw === "NO" || raw === "N") return "DECLINED";
  if (raw === "TENTATIVE" || raw === "MAYBE" || raw === "M") return "TENTATIVE";
  return "";
}

function emailsMatch(left, right) {
  return String(left || "").trim().toLowerCase() === String(right || "").trim().toLowerCase();
}

function userAttendee(event) {
  if (!event) return null;
  var owner = String(event.calendar_owner_email || "").trim();
  if (owner === "") return null;
  var attendees = event.attendees || [];
  for (var i = 0; i < attendees.length; i++) {
    var attendee = attendees[i];
    if (emailsMatch(attendee.email, owner) && attendee.organizer !== true) return attendee;
  }
  return null;
}

function canRsvp(event) {
  return !isReadOnlyEvent(event) && userAttendee(event) !== null;
}

function userRsvpStatus(event) {
  var attendee = userAttendee(event);
  return attendee ? normalizeRsvpStatus(attendee.rsvp_status) : "";
}

function isDeclined(event) {
  return userRsvpStatus(event) === "DECLINED";
}

function awaitingResponse(event) {
  return canRsvp(event) && userRsvpStatus(event) === "";
}

function eventRsvpArgs(event, status) {
  if (!canRsvp(event)) return [];
  var normalized = normalizeRsvpStatus(status);
  var ref = eventReference(event);
  if (normalized === "" || ref === "") return [];
  return ["event", "rsvp", ref, "--status", normalized];
}

function applyUserRsvp(event, status) {
  var normalized = normalizeRsvpStatus(status);
  if (!event || !canRsvp(event) || normalized === "") return event;
  var owner = String(event.calendar_owner_email || "").trim();
  var next = {};
  for (var key in event) next[key] = event[key];
  next.attendees = (event.attendees || []).map(function(attendee) {
    var copy = {};
    for (var field in attendee) copy[field] = attendee[field];
    if (emailsMatch(attendee.email, owner) && attendee.organizer !== true) copy.rsvp_status = normalized;
    return copy;
  });
  return next;
}

function firstUrlInText(value) {
  var match = String(value || "").match(/https?:\/\/[^\s<>()]+/i);
  return match ? match[0].replace(/[.,;:!?]+$/, "") : "";
}

function urlHost(value) {
  var match = String(value || "").match(/^https?:\/\/([^/:?#]+)/i);
  return match ? match[1].toLowerCase() : "";
}

function isGoogleAuthuserHost(host) {
  var name = String(host || "").toLowerCase();
  if (name === "meet.google.com" || name === "calendar.google.com") return true;
  return name === "docs.google.com" || name.slice(-16) === ".docs.google.com";
}

function withGoogleAuthuser(url, email) {
  var address = String(url || "");
  var user = String(email || "").trim();
  if (address === "" || user === "") return address;
  if (/[?&]authuser=/i.test(address)) return address;
  if (!isGoogleAuthuserHost(urlHost(address))) return address;
  var hashIndex = address.indexOf("#");
  var hash = "";
  if (hashIndex >= 0) {
    hash = address.slice(hashIndex);
    address = address.slice(0, hashIndex);
  }
  var separator = address.indexOf("?") >= 0 ? "&" : "?";
  return address + separator + "authuser=" + encodeURIComponent(user) + hash;
}

function eventJoinEmail(event) {
  return event ? String(event.calendar_owner_email || "").trim() : "";
}

function rewriteOpenUrl(url, event) {
  return withGoogleAuthuser(url, eventJoinEmail(event));
}

var CONFERENCE_PROVIDERS = [
  { name: "Google Meet", pattern: /^meet\.google\.com$/ },
  { name: "Zoom", pattern: /(^|\.)zoom\.(us|com)$/ },
  { name: "Teams", pattern: /^teams\.(microsoft|live)\.com$/ },
  { name: "Webex", pattern: /(^|\.)webex\.com$/ },
  { name: "Jitsi", pattern: /^meet\.jit\.si$/ },
  { name: "Whereby", pattern: /(^|\.)whereby\.com$/ },
  { name: "Chime", pattern: /(^|\.)chime\.aws$/ },
  { name: "GoTo", pattern: /(^|\.)(gotomeeting\.com|goto\.com)$/ },
  { name: "Around", pattern: /(^|\.)around\.co$/ },
  { name: "Slack", pattern: /^app\.slack\.com$/ },
  { name: "Discord", pattern: /^(discord\.gg|discord\.com)$/ }
];

function conferenceProvider(url) {
  var host = urlHost(url);
  if (host === "") return "";
  for (var i = 0; i < CONFERENCE_PROVIDERS.length; i++)
    if (CONFERENCE_PROVIDERS[i].pattern.test(host)) return CONFERENCE_PROVIDERS[i].name;
  return "";
}

function urlsInText(value) {
  var matches = String(value || "").match(/https?:\/\/[^\s<>()"]+/ig) || [];
  return matches.map(function(url) { return url.replace(/[.,;:!?]+$/, ""); });
}

function firstConferenceUrlInText(value) {
  var urls = urlsInText(value);
  for (var i = 0; i < urls.length; i++) if (conferenceProvider(urls[i]) !== "") return urls[i];
  return "";
}

// Video-call link only: the explicit conference URI, else a known meeting
// provider found in the URL, location, or notes (Google puts Meet there).
function eventConferenceUrl(event) {
  if (!event) return "";
  var explicit = String(event.conference_url || "");
  if (/^https?:\/\//i.test(explicit)) return rewriteOpenUrl(explicit, event);
  var attached = splitVideoLine(event.description).url;
  if (attached !== "") return rewriteOpenUrl(attached, event);
  var url = String(event.url || "");
  if (conferenceProvider(url) !== "") return rewriteOpenUrl(url, event);
  var found = firstConferenceUrlInText(event.location) || firstConferenceUrlInText(event.description);
  return found === "" ? "" : rewriteOpenUrl(found, event);
}

function eventOpenUrl(event) {
  if (!event) return "";
  var conference = eventConferenceUrl(event);
  if (conference !== "") return conference;
  var url = String(event.url || firstUrlInText(event.location) || firstUrlInText(event.description) || "");
  if (!/^https?:\/\//i.test(url)) return "";
  return rewriteOpenUrl(url, event);
}

// Timed, non-declined events whose start is within `leadMinutes` and that
// started no more than two minutes ago (so a fresh shell does not replay
// alerts for meetings already under way).
function dueReminders(events, nowValue, leadMinutes, seen) {
  var now = parseDate(nowValue) || new Date();
  var lead = Math.max(0, Number(leadMinutes) || 0) * 60000;
  var notified = seen || {};
  return (events || []).filter(function(event) {
    if (event.all_day === true || isDeclined(event) || String(event.status || "").toUpperCase() === "CANCELLED") return false;
    var start = eventStartDate(event);
    if (!start) return false;
    var delta = start.getTime() - now.getTime();
    return delta <= lead && delta > -120000 && notified[eventKey(event)] === undefined;
  });
}

function pruneReminderKeys(seen, nowValue) {
  var now = parseDate(nowValue) || new Date();
  var kept = {};
  for (var key in seen) {
    var end = parseDate(seen[key]);
    if (!end || end.getTime() > now.getTime()) kept[key] = seen[key];
  }
  return kept;
}

function reminderBody(event, nowValue) {
  var now = parseDate(nowValue) || new Date();
  var start = eventStartDate(event);
  var lead = start && start.getTime() > now.getTime() ? "Starts " + "in " + durationLabel((start.getTime() - now.getTime()) / 1000) : "Starting now";
  var parts = [lead + " · " + formatEventRange(event)];
  if (event.location && firstUrlInText(event.location) === "") parts.push(String(event.location));
  return parts.join("\n");
}

function eventJoinLabel(event) {
  var conference = eventConferenceUrl(event);
  if (conference === "") return eventOpenUrl(event) !== "" ? "Open link" : "";
  var provider = conferenceProvider(conference);
  return provider === "" ? "Join" : "Join " + provider;
}

// The meeting a "join next" action should open: an ongoing call first, then
// the next one starting today. Declined invitations are skipped.
function joinableEvent(events, nowValue) {
  var now = parseDate(nowValue) || new Date();
  var candidates = (events || []).filter(function(event) {
    return event.all_day !== true && !isDeclined(event) && !eventHasEnded(event, now) && eventConferenceUrl(event) !== "";
  }).sort(eventSort);
  for (var i = 0; i < candidates.length; i++) if (eventIsOngoing(candidates[i], now)) return candidates[i];
  var todayKey = dateKey(now);
  for (var j = 0; j < candidates.length; j++)
    if (dateKey(eventStartDate(candidates[j])) === todayKey) return candidates[j];
  return null;
}

function chroncalLaunchArgs(event) {
  var args = ["chroncal"];
  if (!event) return args;
  var id = event.id;
  if (id === undefined || id === null || String(id) === "") return args;
  args.push("--event", String(id));
  var at = String(event.start_time || "").trim();
  if (at !== "") args.push("--at", at);
  return args;
}

function showOpenInChroncalEnabled(settings) {
  return optionEnabled(settings, "showOpenInChroncal", false);
}

// Drops the dial-in blocks Google Meet and Microsoft Teams append to
// invitations; the Join button already carries that link.
function decodeEntities(value) {
  return String(value || "").replace(/&(#x[0-9a-f]+|#\d+|[a-z]+);/gi, function(entity, code) {
    var named = { amp: "&", lt: "<", gt: ">", quot: "\"", apos: "'", nbsp: " " };
    var lower = code.toLowerCase();
    if (lower in named) return named[lower];
    var number = lower.charAt(1) === "x" ? parseInt(lower.slice(2), 16) : (lower.charAt(0) === "#" ? parseInt(lower.slice(1), 10) : NaN);
    return isFinite(number) && number > 0 && number < 0x110000 ? String.fromCodePoint(number) : entity;
  });
}

function looksLikeHtml(value) {
  return /<\/?(a|b|i|u|p|br|div|span|strong|em|ol|ul|li|h[1-6]|html|body|font)\b[^>]*>/i.test(String(value || ""));
}

// Google stores rich notes as HTML. Turn them into text, keeping each link
// as a Markdown-style [label](url) so the panel can show the label.
function htmlToNotesText(value) {
  var text = String(value || "");
  if (!looksLikeHtml(text)) return text;
  var links = [];
  // Links become placeholders so tag stripping and entity decoding run
  // once over the surrounding text and never touch a decoded label.
  text = text.replace(/\r\n/g, "\n").replace(/\u0000/g, "");
  text = text.replace(/<a\b[^>]*?\bhref\s*=\s*(?:"([^"]*)"|'([^']*)'|([^\s>]+))[^>]*>([\s\S]*?)<\/a\s*>/gi,
    function(match, doubleQuoted, singleQuoted, bare, inner) {
      var href = decodeEntities(doubleQuoted || singleQuoted || bare || "").trim();
      var label = decodeEntities(inner.replace(/<[^>]*>/g, "")).replace(/\s+/g, " ").trim();
      var out;
      if (!/^(https?:\/\/|mailto:)\S+$/i.test(href)) out = label;
      else if (label === "" || label === href) out = href;
      else out = "[" + label.replace(/[\[\]]/g, "") + "](" + href.replace(/[()]/g, encodeURIComponent) + ")";
      links.push(out);
      return "\u0000" + (links.length - 1) + "\u0000";
    });
  text = text.replace(/<br\s*\/?>/gi, "\n");
  text = text.replace(/<li\b[^>]*>/gi, "\n• ");
  text = text.replace(/<\/(p|div|ol|ul|h[1-6])\s*>/gi, "\n");
  text = decodeEntities(text.replace(/<[^>]*>/g, ""));
  text = text.replace(/\u0000(\d+)\u0000/g, function(match, index) { return links[Number(index)]; });
  return text.replace(/[ \t]+\n/g, "\n").replace(/\n{3,}/g, "\n\n");
}

// Plain-text form for copying: [label](url) becomes "label (url)".
function notesPlainText(value) {
  return String(value || "").replace(/\[([^\]\n]+)\]\(((?:https?:\/\/|mailto:)[^\s)]+)\)/g, "$1 ($2)");
}

function cleanDescription(value) {
  var text = splitVideoLine(htmlToNotesText(value)).text;
  text = text.replace(/-::~[:~]*::-[\s\S]*?-::~[:~]*::-/g, "");
  text = text.replace(/_{30,}[\s\S]*?Microsoft Teams[\s\S]*?_{30,}/g, "");
  return text.replace(/\n{3,}/g, "\n\n").trim();
}

function eventNotesHtml(event, linkColor) {
  var text = event ? cleanDescription(event.description) : "";
  if (text === "") return "";
  var email = eventJoinEmail(event);
  var color = htmlColor(linkColor);
  var pattern = /\[([^\]\n]+)\]\(((?:https?:\/\/|mailto:)[^\s)]+)\)|https?:\/\/[^\s<>()]+/ig;
  var html = "";
  var lastIndex = 0;
  var match;
  while ((match = pattern.exec(text)) !== null) {
    if (match[1] !== undefined) {
      html += escapeHtml(text.slice(lastIndex, match.index)).replace(/\n/g, "<br/>");
      var linkHref = /^mailto:/i.test(match[2]) ? match[2] : withGoogleAuthuser(match[2], email);
      var linkLabel = escapeHtml(match[1]);
      if (color !== "") linkLabel = '<font color="' + color + '">' + linkLabel + "</font>";
      html += '<a href="' + escapeHtml(linkHref) + '">' + linkLabel + "</a>";
      lastIndex = match.index + match[0].length;
      continue;
    }
    var raw = match[0];
    var trailing = "";
    var cleaned = raw.replace(/[.,;:!?]+$/, function(punctuation) {
      trailing = punctuation;
      return "";
    });
    html += escapeHtml(text.slice(lastIndex, match.index)).replace(/\n/g, "<br/>");
    if (cleaned !== "") {
      var href = withGoogleAuthuser(cleaned, email);
      var label = escapeHtml(cleaned);
      if (color !== "") label = '<font color="' + color + '">' + label + "</font>";
      html += '<a href="' + escapeHtml(href) + '">' + label + "</a>";
    }
    html += escapeHtml(trailing);
    lastIndex = match.index + raw.length;
  }
  html += escapeHtml(text.slice(lastIndex)).replace(/\n/g, "<br/>");
  return html;
}

function eventMapUrl(event) {
  var location = event ? String(event.location || "") : "";
  var direct = firstUrlInText(location);
  if (direct !== "") return direct;
  return location === "" ? "" : "https://www.google.com/maps/search/?api=1&query=" + encodeURIComponent(location);
}

function titleCase(value) {
  var text = String(value || "").toLocaleLowerCase();
  return text === "" ? "" : text.charAt(0).toLocaleUpperCase() + text.slice(1);
}

function eventAttributes(event) {
  if (!event) return "";
  var values = [];
  if (event.status) values.push(titleCase(event.status));
  if (event.class) values.push(titleCase(event.class));
  values.push(String(event.transp || "OPAQUE").toLocaleUpperCase() === "TRANSPARENT" ? "Free" : "Busy");
  if (event.recurrence_rule || event.rdates || event.recurrence_id) values.push("Recurring");
  if (isReadOnlyEvent(event)) values.push("Read-only calendar");
  return values.join(" · ");
}

function humanRsvp(value) {
  var normalized = normalizeRsvpStatus(value);
  if (normalized === "ACCEPTED") return "Going";
  if (normalized === "DECLINED") return "Declined";
  if (normalized === "TENTATIVE") return "Maybe";
  return "Awaiting";
}

function attendeeStatusLabel(attendee) {
  if (attendee && attendee.organizer === true) return "Organizer";
  return humanRsvp(attendee && attendee.rsvp_status);
}

function attendeeCounts(event) {
  var attendees = event && event.attendees ? event.attendees : [];
  var counts = { total: attendees.length, yes: 0, no: 0, maybe: 0, awaiting: 0 };
  attendees.forEach(function(attendee) {
    var status = normalizeRsvpStatus(attendee.rsvp_status);
    if (attendee.organizer === true || status === "ACCEPTED") counts.yes += 1;
    else if (status === "DECLINED") counts.no += 1;
    else if (status === "TENTATIVE") counts.maybe += 1;
    else counts.awaiting += 1;
  });
  return counts;
}

function attendeeCountsLabel(event) {
  var counts = attendeeCounts(event);
  if (counts.total === 0) return "";
  var parts = [counts.total + (counts.total === 1 ? " guest" : " guests")];
  var detail = [];
  if (counts.yes > 0) detail.push(counts.yes + " yes");
  if (counts.maybe > 0) detail.push(counts.maybe + " maybe");
  if (counts.no > 0) detail.push(counts.no + " no");
  if (counts.awaiting > 0) detail.push(counts.awaiting + " awaiting");
  return parts.concat(detail).join(" · ");
}

function attendeeDisplayName(attendee) {
  var name = String(attendee && attendee.name || "").trim();
  var email = String(attendee && attendee.email || "").trim();
  if (name !== "" && !emailsMatch(name, email)) return name;
  return email !== "" ? email : (name !== "" ? name : "Guest");
}

function sortedAttendees(event) {
  var rank = { organizer: 0, ACCEPTED: 1, TENTATIVE: 2, "": 3, DECLINED: 4 };
  var attendees = (event && event.attendees ? event.attendees : []).slice();
  return attendees.sort(function(left, right) {
    var leftRank = left.organizer === true ? 0 : rank[normalizeRsvpStatus(left.rsvp_status)];
    var rightRank = right.organizer === true ? 0 : rank[normalizeRsvpStatus(right.rsvp_status)];
    if (leftRank !== rightRank) return leftRank - rightRank;
    return attendeeDisplayName(left).localeCompare(attendeeDisplayName(right));
  });
}

function organizerLabel(event) {
  var attendees = event && event.attendees ? event.attendees : [];
  for (var i = 0; i < attendees.length; i++) {
    if (attendees[i].organizer === true) {
      var owner = String(event.calendar_owner_email || "");
      return owner !== "" && emailsMatch(attendees[i].email, owner) ? "You" : attendeeDisplayName(attendees[i]);
    }
  }
  return "";
}

function attendeeSummary(event) {
  var attendees = event && event.attendees ? event.attendees : [];
  return sortedAttendees({ attendees: attendees }).map(function(attendee) {
    return attendeeDisplayName(attendee) + " · " + attendeeStatusLabel(attendee);
  }).join("\n");
}

function eventDetailsText(event, nowValue) {
  if (!event) return "";
  var lines = [String(event.title || "Untitled")];
  var dateLine = formatEventDate(event, nowValue);
  if (dateLine) lines.push(dateLine);
  lines.push(formatEventRange(event));
  if (event.calendar_name) lines.push(String(event.calendar_name));
  if (event.location) lines.push(String(event.location));
  var notes = notesPlainText(cleanDescription(event.description));
  if (notes) lines.push(notes);
  var link = eventOpenUrl(event);
  if (link && notes.indexOf(link) === -1) lines.push(link);
  var attendees = event.attendees || [];
  sortedAttendees(event).forEach(function(attendee) {
    var identity = attendeeDisplayName(attendee);
    var email = attendee.email && identity !== attendee.email ? " <" + attendee.email + ">" : "";
    lines.push(identity + email + " · " + attendeeStatusLabel(attendee));
  });
  return lines.join("\n");
}

// Video calls the editor attaches live on one "Video call: <url>" line in
// the notes: Google drops the iCalendar URL property on sync, but keeps the
// description, and guests see the link there too.
var VIDEO_LINE = /^Video call: (https?:\/\/\S+)\s*$/;

function splitVideoLine(description) {
  var lines = String(description || "").replace(/\r\n/g, "\n").split("\n");
  var url = "";
  var kept = [];
  for (var i = 0; i < lines.length; i++) {
    var match = url === "" ? VIDEO_LINE.exec(lines[i]) : null;
    if (match) url = match[1];
    else kept.push(lines[i]);
  }
  return { url: url, text: kept.join("\n").replace(/\s+$/, "") };
}

function composeDescription(text, videoUrl) {
  var body = String(text || "").replace(/\r\n/g, "\n").replace(/\s+$/, "");
  var url = String(videoUrl || "").trim();
  if (url === "") return body;
  return body === "" ? "Video call: " + url : body + "\n\nVideo call: " + url;
}

function isVideoUrl(value) {
  var text = String(value || "").trim();
  return text === "" || /^https?:\/\/[^\s]+\.[^\s]+$/i.test(text);
}

// Label for the editor's quick-add button, e.g. "Add Zoom".
function videoLinkLabel(url) {
  var provider = conferenceProvider(url);
  return provider === "" ? "Add my link" : "Add " + provider;
}

// ---- Mini month calendar ----

// Day keys that have at least one event, with up to three calendar colors
// each. Multi-day events mark every local day they overlap.
function eventDayMarkers(events) {
  var markers = {};
  var source = events || [];
  for (var i = 0; i < source.length; i++) {
    var event = source[i];
    var start = eventStartDate(event);
    var end = eventEndDate(event);
    if (!start) continue;
    if (!end || end <= start) end = new Date(start.getTime() + 1);
    var cursor = startOfLocalDay(start);
    for (var guard = 0; guard < 62 && cursor < end; guard++) {
      var key = dateKey(cursor);
      var colors = markers[key] || (markers[key] = []);
      var color = calendarColor(event);
      if (colors.length < 3 && colors.indexOf(color) < 0) colors.push(color);
      cursor = new Date(cursor.getFullYear(), cursor.getMonth(), cursor.getDate() + 1);
    }
  }
  return markers;
}

// First agenda row listed on or after a day (the panel scrolls there).
function firstEventIndexOnOrAfterDay(events, dayKeyValue, nowValue) {
  var now = parseDate(nowValue) || new Date();
  var source = events || [];
  for (var i = 0; i < source.length; i++)
    if (eventAgendaDayKey(source[i], now) >= String(dayKeyValue)) return i;
  return -1;
}

function miniCalendarWeeks(year, month, weekStart, todayKey, selectedKey, markers, rangeFrom, rangeTo) {
  var weeks = monthGrid(year, month, weekStart, todayKey, selectedKey);
  var marks = markers || {};
  for (var w = 0; w < weeks.length; w++) {
    for (var d = 0; d < weeks[w].length; d++) {
      var day = weeks[w][d];
      day.colors = marks[day.key] || [];
      day.loaded = (!rangeFrom || day.key >= rangeFrom) && (!rangeTo || day.key <= rangeTo);
      day.past = day.key < String(todayKey || "");
    }
  }
  // Drop a trailing week that lies wholly in the next month.
  if (weeks.length === 6 && !weeks[5].some(function(day) { return day.inMonth; })) weeks.pop();
  return weeks;
}

// ---- Share availability ----

function isBusyEvent(event) {
  if (!event) return false;
  if (String(event.status || "").toUpperCase() === "CANCELLED") return false;
  if (String(event.transp || "OPAQUE").toUpperCase() === "TRANSPARENT") return false;
  return !isDeclined(event);
}

function clampHour(value, fallback) {
  var number = Number(value);
  if (!isFinite(number)) return fallback;
  return Math.max(0, Math.min(24, Math.round(number)));
}

// Free time inside working hours over the next `days` working days.
// options: days, startHour, endHour, minMinutes, weekends, rangeTo (last
// loaded day key; later days are unknown and never offered).
function availabilitySlots(events, nowValue, options) {
  var opts = options || {};
  var now = parseDate(nowValue) || new Date();
  var wanted = Math.max(1, Math.min(14, Number(opts.days) || 3));
  var startHour = clampHour(opts.startHour, 9);
  var endHour = clampHour(opts.endHour, 18);
  var minimum = Math.max(5, Number(opts.minMinutes) || 30) * 60000;
  var weekends = opts.weekends === true;
  var rangeTo = String(opts.rangeTo || "");
  if (endHour <= startHour) return [];

  var busy = [];
  (events || []).forEach(function(event) {
    if (!isBusyEvent(event)) return;
    var start = eventStartDate(event);
    var end = eventEndDate(event);
    if (start && end && end > start) busy.push({ start: start.getTime(), end: end.getTime() });
  });
  busy.sort(function(left, right) { return left.start - right.start; });

  var result = [];
  var cursor = startOfLocalDay(now);
  for (var guard = 0; guard < 60 && result.length < wanted; guard++) {
    var key = dateKey(cursor);
    if (rangeTo !== "" && key > rangeTo) break;
    var weekday = cursor.getDay();
    var dayStart = new Date(cursor.getFullYear(), cursor.getMonth(), cursor.getDate(), startHour).getTime();
    var dayEnd = new Date(cursor.getFullYear(), cursor.getMonth(), cursor.getDate(), endHour).getTime();
    // Today starts at the next quarter hour.
    var quarter = 15 * 60000;
    var from = Math.max(dayStart, Math.ceil(now.getTime() / quarter) * quarter);
    if ((weekends || (weekday !== 0 && weekday !== 6)) && from < dayEnd) {
      var slots = [];
      var free = from;
      for (var b = 0; b < busy.length && free < dayEnd; b++) {
        if (busy[b].end <= free || busy[b].start >= dayEnd) continue;
        if (busy[b].start - free >= minimum) slots.push({ start: new Date(free), end: new Date(busy[b].start) });
        free = Math.max(free, busy[b].end);
      }
      if (dayEnd - free >= minimum) slots.push({ start: new Date(free), end: new Date(dayEnd) });
      result.push({ key: key, label: dayLabel(cursor, now), detail: shortDateLabel(cursor), slots: slots });
    }
    cursor = new Date(cursor.getFullYear(), cursor.getMonth(), cursor.getDate() + 1);
  }
  return result;
}

function slotLabel(slot) {
  return formatTime(slot.start) + "–" + formatTime(slot.end);
}

function gmtOffsetLabel(date) {
  var offset = -(date || new Date()).getTimezoneOffset();
  var sign = offset >= 0 ? "+" : "-";
  var hours = Math.floor(Math.abs(offset) / 60);
  var minutes = Math.abs(offset) % 60;
  return "GMT" + sign + hours + (minutes ? ":" + pad2(minutes) : "");
}

function availabilityText(days, timezone, nowValue) {
  var withSlots = (days || []).filter(function(day) { return day.slots.length > 0; });
  if (withSlots.length === 0) return "";
  var now = parseDate(nowValue) || new Date();
  var zone = String(timezone || "");
  var lines = ["My availability (" + (zone !== "" ? zone.replace(/_/g, " ") + ", " : "") + gmtOffsetLabel(now) + "):"];
  withSlots.forEach(function(day) {
    lines.push("• " + day.detail + ": " + day.slots.map(slotLabel).join(", "));
  });
  return lines.join("\n");
}

// WCAG relative luminance of a color (#rgb, #rrggbb, #aarrggbb or a QML color).
function relativeLuminance(value) {
  var match = htmlColor(value).match(/^#([0-9A-Fa-f]{2})([0-9A-Fa-f]{2})([0-9A-Fa-f]{2})$/);
  if (!match) return NaN;
  function linear(part) {
    var c = parseInt(part, 16) / 255;
    return c <= 0.03928 ? c / 12.92 : Math.pow((c + 0.055) / 1.055, 2.4);
  }
  return 0.2126 * linear(match[1]) + 0.7152 * linear(match[2]) + 0.0722 * linear(match[3]);
}

function contrastRatio(a, b) {
  var la = relativeLuminance(a);
  var lb = relativeLuminance(b);
  if (!isFinite(la) || !isFinite(lb)) return 1;
  return (Math.max(la, lb) + 0.05) / (Math.min(la, lb) + 0.05);
}

// The candidate that reads best on `background`. Theme colors come first so
// the label stays on-palette; plain black and white step in when neither
// theme color clears 4.5:1 (a mid-tone calendar color on a mid-tone theme).
function readableTextColor(background, candidates) {
  var list = (candidates || []).map(htmlColor).filter(function(color) { return !!color; });
  var best = "";
  var bestRatio = 0;
  list.forEach(function(color) {
    var ratio = contrastRatio(background, color);
    if (ratio > bestRatio) { best = color; bestRatio = ratio; }
  });
  if (bestRatio >= 4.5) return best;
  return contrastRatio(background, "#000000") >= contrastRatio(background, "#ffffff") ? "#000000" : "#ffffff";
}
