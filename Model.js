function pad2(value) {
  return value < 10 ? "0" + value : String(value);
}

function parseDate(value) {
  var date = new Date(value);
  return isNaN(date.getTime()) ? null : date;
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
  return String(left.start_time).localeCompare(String(right.start_time));
}

function groupEvents(events, nowValue) {
  var now = parseDate(nowValue) || new Date();
  var sorted = (events || []).slice().sort(function(left, right) {
    var leftDate = String(left.start_time);
    var rightDate = String(right.start_time);
    if (leftDate !== rightDate) {
      var leftKey = dateKey(parseDate(leftDate));
      var rightKey = dateKey(parseDate(rightDate));
      if (leftKey !== rightKey) return leftKey < rightKey ? -1 : 1;
    }
    return eventSort(left, right);
  });
  var groups = [];
  var byKey = {};

  for (var index = 0; index < sorted.length; index++) {
    var event = sorted[index];
    var start = parseDate(event.start_time);
    if (!start) continue;
    var key = dateKey(start);
    var group = byKey[key];
    if (!group) {
      group = { key: key, label: dayLabel(start, now), events: [] };
      byKey[key] = group;
      groups.push(group);
    }
    group.events.push(event);
  }

  return groups;
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
  var end = parseDate(event && event.end_time);
  if (!end) return parseDate(event && event.start_time);
  if (event && event.all_day === true) return new Date(end.getTime() - 1);
  return end;
}

function formatEventDate(event, nowValue) {
  var start = parseDate(event && event.start_time);
  if (!start) return "";
  var now = parseDate(nowValue) || new Date();
  var end = eventInclusiveEnd(event) || start;
  var startLabel = formatInspectorDate(start, now);
  if (dateKey(start) === dateKey(end)) return startLabel;
  return startLabel + " – " + formatInspectorDate(end, now);
}

function eventProgress(event, nowValue) {
  if (!event || event.all_day === true) return 0;
  var start = parseDate(event.start_time);
  var end = parseDate(event.end_time);
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
    var start = parseDate(events[index].start_time);
    if (start && dateKey(start) === today) return index;
  }
  return -1;
}

function eventDateKey(event) {
  var start = parseDate(event && event.start_time);
  return start ? dateKey(start) : "";
}

function firstEventIndexForDay(events, dayKey) {
  var key = String(dayKey || "");
  if (key === "") return -1;
  for (var index = 0; index < (events || []).length; index += 1) {
    if (eventDateKey(events[index]) === key) return index;
  }
  return -1;
}

function adjacentDayFirstEventIndex(events, currentIndex, direction) {
  var list = events || [];
  if (list.length === 0 || direction === 0) return -1;
  var current = currentIndex >= 0 && currentIndex < list.length ? list[currentIndex] : null;
  var currentKey = eventDateKey(current);
  var targetKey = "";
  for (var index = 0; index < list.length; index += 1) {
    var key = eventDateKey(list[index]);
    if (key === "") continue;
    if (direction > 0) {
      if ((currentKey === "" || key > currentKey) && (targetKey === "" || key < targetKey)) targetKey = key;
    } else if (currentKey !== "" && key < currentKey && (targetKey === "" || key > targetKey)) {
      targetKey = key;
    }
  }
  return firstEventIndexForDay(list, targetKey);
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
  var start = parseDate(event.start_time);
  var end = parseDate(event.end_time);
  if (!start || !end) return "";
  var untilStart = (start.getTime() - now.getTime()) / 1000;
  if (untilStart > 0) {
    var dayLabel = relativeDayLabel(start, now);
    if (dayLabel !== "") return dayLabel + " " + formatTime(event.start_time);
    var leadSeconds = Math.max(0, Number(relativeLeadMinutes === undefined ? 10 : relativeLeadMinutes)) * 60;
    return untilStart <= leadSeconds ? "in " + durationLabel(untilStart) : formatTime(event.start_time);
  }
  if ((now.getTime() - start.getTime()) < 60000) return "Now";
  return durationLabel((end.getTime() - now.getTime()) / 1000) + " left";
}

function colorBlock(event) {
  return '<font color="' + escapeHtml(event.calendar_color || "#888888") + '">■</font>';
}

function tooltipLine(event) {
  var when = event.all_day === true ? "All day" : formatEventRange(event);
  return colorBlock(event) + "  " + when + " · " + escapeHtml(event.title || "Untitled");
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

  return source.filter(function(event) {
    if (selectionCustomized && included.indexOf(String(event.calendar_id)) === -1) return false;
    if (!showAllDay && event.all_day === true) return false;
    if (!showWithoutParticipants && (!event.attendees || event.attendees.length === 0)) return false;
    if (!showWithoutLocation && !event.location && !event.conference_url) return false;
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

function barPresentation(agenda, maximumTitleLength, displayOptions) {
  if (!agenda || agenda.status !== "ok") {
    return { text: "", className: "unavailable", tooltip: "chroncal unavailable" };
  }

  var events = agenda.events || [];
  var tooltip = richText(events.length === 0 ? "No upcoming events" : events.map(tooltipLine).join("<br>"));
  if (events.length === 0) return { text: "", className: "empty", tooltip: tooltip };

  var now = parseDate(agenda.generated_at) || new Date();
  var anchor = events[0];
  var titleLimit = maximumTitleLength || 42;
  var showTime = optionEnabled(displayOptions, "showTime", true);
  var showTitle = optionEnabled(displayOptions, "showTitle", true);
  var relativeLeadMinutes = Number(displayOptions && displayOptions.relativeLeadMinutes !== undefined ? displayOptions.relativeLeadMinutes : 10);
  if (anchor.all_day === true) {
    var allDayParts = [];
    if (showTime) allDayParts.push("All day");
    if (showTitle) allDayParts.push(escapeHtml(truncate(anchor.title, titleLimit)));
    return {
      text: allDayParts.length > 0 ? richText(" " + allDayParts.join(" · ") + " ") : "",
      className: "all-day",
      tooltip: tooltip
    };
  }

  var anchorStart = parseDate(anchor.start_time);
  var anchorEnd = parseDate(anchor.end_time);
  var active = anchorStart && anchorEnd && anchorStart <= now && anchorEnd > now;
  var className = active ? "in-progress" : "upcoming";
  var cluster = events.filter(function(event) {
    if (event.all_day === true) return false;
    var start = parseDate(event.start_time);
    var end = parseDate(event.end_time);
    return start && end && anchorStart && anchorEnd && start < anchorEnd && anchorStart < end;
  });

  if (cluster.length <= 1) {
    var parts = [];
    if (showTime) parts.push(eventLeadLabel(anchor, now, relativeLeadMinutes));
    if (showTitle) parts.push(escapeHtml(truncate(anchor.title, titleLimit)));
    return {
      text: parts.length > 0 ? richText(" " + parts.join(" · ") + " ") : "",
      className: className,
      tooltip: tooltip
    };
  }

  var visible = cluster.slice(0, 3).map(function(event) {
    var eventParts = [];
    if (showTime) eventParts.push(eventLeadLabel(event, now, relativeLeadMinutes));
    if (showTitle) eventParts.push(escapeHtml(truncate(event.title, 18)));
    return colorBlock(event) + (eventParts.length > 0 ? " " + eventParts.join(" · ") : "");
  }).join(" | ");
  var more = cluster.length > 3 ? " +" + (cluster.length - 3) : "";
  return {
    text: richText(" " + visible + more + " "),
    className: [className, "overlap"],
    tooltip: tooltip
  };
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
      description: String(event.description || ""),
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

function canEditEvent(event) {
  return eventReference(event) !== "";
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
    if (String(event.timezone || "") !== "" && (dateChanged || timeChanged || durationChanged)) return [];
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
    if (String(form.description || "") !== String(original.description || ""))
      args.push("--description", String(form.description || ""));
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
  pushOptionalFlag(args, "--description", form.description);
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
  return userAttendee(event) !== null;
}

function userRsvpStatus(event) {
  var attendee = userAttendee(event);
  return attendee ? normalizeRsvpStatus(attendee.rsvp_status) : "";
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

function eventOpenUrl(event) {
  if (!event) return "";
  var url = String(event.conference_url || event.url || firstUrlInText(event.location) || firstUrlInText(event.description) || "");
  return rewriteOpenUrl(url, event);
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

function defaultAccountServer(auth) {
  return String(auth || "") === "oauth2" ? "https://apidata.googleusercontent.com/caldav" : "";
}

function accountAddArgs(form) {
  var values = form || {};
  var server = String(values.server || "").trim() || defaultAccountServer(values.auth);
  var args = ["account", "add"];
  if (!serverHasCredentials(server)) pushOptionalFlag(args, "--server", server);
  pushOptionalFlag(args, "--username", values.username);
  pushOptionalFlag(args, "--auth", values.auth);
  pushOptionalFlag(args, "--oauth-client-id", values.clientId);
  if (values.allowInsecure === true || isLoopbackHttpServer(server)) args.push("--allow-insecure");
  args.push("--output", "json", "--", String(values.name || "").trim());
  return args;
}

function accountSecretEnv(auth, password, token, clientSecret) {
  var env = {};
  var type = String(auth || "");
  if (type === "basic" && String(password || "") !== "") env.CHRONCAL_PASSWORD = String(password);
  if (type === "bearer" && String(token || "") !== "") env.CHRONCAL_BEARER_TOKEN = String(token);
  if (type === "oauth2" && String(clientSecret || "") !== "") env.GOOGLE_CLIENT_SECRET = String(clientSecret);
  return env;
}

function accountAddEnv(form) {
  var values = form || {};
  return accountSecretEnv(values.auth, values.password, values.token, values.clientSecret);
}

function accountCredentialsEnv(form) {
  var values = form || {};
  return accountSecretEnv(values.auth, values.password, values.token, "");
}

function serverHost(value) {
  var match = String(value || "").match(/^https?:\/\/(\[[^\]]+\]|[^\/:?#]+)/i);
  return match ? match[1].toLowerCase().replace(/^\[|\]$/g, "") : "";
}

function isLoopbackHost(host) {
  var name = String(host || "").toLowerCase();
  return name === "localhost" || name === "127.0.0.1" || name === "::1";
}

function isLoopbackHttpServer(value) {
  return /^http:\/\//i.test(String(value || "")) && isLoopbackHost(serverHost(value));
}

function serverHasCredentials(value) {
  return /:\/\/[^\/?#]*@/.test(String(value || ""));
}

function validateAccountForm(form) {
  var values = form || {};
  var errors = [];
  var auth = String(values.auth || "");
  if (String(values.name || "").trim() === "") errors.push("Account name is required");
  if (auth !== "basic" && auth !== "bearer" && auth !== "oauth2") errors.push("Choose a sign-in method");
  var server = String(values.server || "").trim() || defaultAccountServer(auth);
  if (server === "" && auth !== "oauth2") errors.push("Server URL is required");
  if (String(values.username || "").trim() === "") errors.push("Username is required");
  if (serverHasCredentials(server)) errors.push("Server URL must not include credentials");
  if (auth === "basic" && String(values.password || "") === "") errors.push("Password is required");
  if (auth === "bearer" && String(values.token || "") === "") errors.push("Bearer token is required");
  if (auth === "oauth2") {
    if (String(values.clientId || "").trim() === "") errors.push("OAuth client ID is required");
    if (String(values.clientSecret || "") === "") errors.push("OAuth client secret is required");
  }
  if (/^http:\/\//i.test(server) && !isLoopbackHttpServer(server) && values.allowInsecure !== true)
    errors.push("Server URL uses plain HTTP; enable Allow HTTP (insecure) or use HTTPS");
  return errors;
}

function accountsFromCalendars(calendars) {
  // Until the agenda adapter ships an `accounts[]` document, unique
  // accounts are derived from the calendar list. Local calendars carry
  // no usable account id (0, "0", null, or empty).
  var order = [];
  var byId = {};
  var list = calendars || [];
  for (var i = 0; i < list.length; i += 1) {
    var calendar = list[i] || {};
    var rawId = calendar.account_id;
    if (rawId === undefined || rawId === null || rawId === 0 || rawId === "0" || String(rawId) === "") continue;
    var key = String(rawId);
    var account = byId[key];
    if (!account) {
      var label = String(calendar.account_name || "") || "Account";
      account = {
        id: rawId,
        display_name: label,
        name: label,
        server_url: String(calendar.remote_url || ""),
        username: "",
        auth_type: "",
        calendar_count: 1
      };
      byId[key] = account;
      order.push(account);
    } else {
      account.calendar_count += 1;
    }
  }
  return order;
}

function groupCalendars(calendars, accounts) {
  // Settings list sections: one per known account (zero-calendar accounts
  // included so Open stays reachable), then accounts derived from unmatched
  // calendar ids (accounts fetch failed or stale), then locals.
  var sections = [];
  var byAccountId = {};
  var accountList = accounts || [];
  for (var a = 0; a < accountList.length; a += 1) {
    var account = accountList[a] || {};
    var section = { account: account, calendars: [] };
    byAccountId[String(account.id)] = section;
    sections.push(section);
  }
  var derived = [];
  var derivedById = {};
  var local = null;
  var list = calendars || [];
  for (var i = 0; i < list.length; i += 1) {
    var calendar = list[i] || {};
    var rawId = calendar.account_id;
    if (rawId === undefined || rawId === null || rawId === 0 || rawId === "0" || String(rawId) === "") {
      if (!local) local = { account: null, calendars: [] };
      local.calendars.push(calendar);
      continue;
    }
    var accountId = String(rawId);
    var target = byAccountId[accountId];
    if (target) {
      target.calendars.push(calendar);
      continue;
    }
    var derivedSection = derivedById[accountId];
    if (!derivedSection) {
      var label = String(calendar.account_name || "") || "Account";
      derivedSection = {
        account: {
          id: rawId,
          display_name: label,
          name: label,
          server_url: String(calendar.remote_url || ""),
          username: "",
          auth_type: "",
          calendar_count: 1
        },
        calendars: []
      };
      derivedById[accountId] = derivedSection;
      derived.push(derivedSection);
    } else {
      derivedSection.account.calendar_count += 1;
    }
    derivedSection.calendars.push(calendar);
  }
  for (var d = 0; d < derived.length; d += 1) sections.push(derived[d]);
  if (local) sections.push(local);
  return sections;
}

function accountCalendarsListArgs(account) {
  return ["account", "calendars", "list", String((account || {}).id || ""), "--output", "json"];
}

function calendarCreateArgs(form) {
  var values = form || {};
  var args = ["calendar", "create"];
  pushOptionalFlag(args, "--color", values.color);
  pushOptionalFlag(args, "--description", values.description);
  pushOptionalFlag(args, "--email", values.email);
  args.push("--output", "json", "--", String(values.title || "").trim());
  return args;
}

function pushClearableFlag(args, flag, values, key) {
  // Chroncal only changes flags it received, so clearing description or
  // owner email requires sending the flag with an empty value. Callers that
  // omit the key (disconnect) must not wipe the stored fields.
  if (key in values) args.push(flag, String(values[key] || ""));
}

function calendarUpdateArgs(form) {
  var values = form || {};
  var args = ["calendar", "update", String(values.id || "")];
  pushOptionalFlag(args, "--name", values.name);
  pushOptionalFlag(args, "--color", values.color);
  pushClearableFlag(args, "--description", values, "description");
  pushClearableFlag(args, "--email", values, "email");
  if (values.disconnectRemote === true) args.push("--disconnect-remote");
  args.push("--output", "json");
  return args;
}

function calendarHideArgs(calendar) {
  return ["calendar", "hide", String((calendar || {}).id || ""), "--output", "json"];
}

function calendarShowArgs(calendar) {
  return ["calendar", "show", String((calendar || {}).id || ""), "--output", "json"];
}

function calendarSetDefaultArgs(calendar) {
  return ["calendar", "set-default", String((calendar || {}).id || ""), "--output", "json"];
}

function calendarDeleteArgs(calendar) {
  var values = calendar || {};
  var args = ["calendar", "delete", String(values.id || "")];
  pushOptionalFlag(args, "--promote", values.promote);
  args.push("--yes", "--output", "json");
  return args;
}

function accountUpdateArgs(form) {
  var values = form || {};
  var args = ["account", "update", String(values.id || "")];
  pushOptionalFlag(args, "--name", values.name);
  args.push("--output", "json");
  return args;
}

function accountCredentialsArgs(form) {
  return ["account", "credentials", String((form || {}).id || ""), "--output", "json"];
}

function accountReauthArgs(form) {
  var values = form || {};
  var args = ["account", "reauth", String(values.id || "")];
  pushOptionalFlag(args, "--oauth-client-id", values.clientId);
  args.push("--output", "json");
  return args;
}

function accountGetArgs(form) {
  return ["account", "get", String((form || {}).id || ""), "--output", "json"];
}

 function accountRemoveArgs(account) {
   return ["account", "remove", String((account || {}).id || ""), "--yes", "--output", "json"];
 }
function accountCalendarsSetArgs(options) {
  var values = options || {};
  var paths = [];
  for (var i = 0; i < (values.paths || []).length; i += 1) {
    var path = String(values.paths[i] || "").trim();
    if (path !== "") paths.push(path);
  }
  var all = values.all === true;
  var none = values.none === true;
  if ((paths.length > 0 ? 1 : 0) + (all ? 1 : 0) + (none ? 1 : 0) !== 1) return [];
  var args = ["account", "calendars", "set", String(values.id || ""), "--yes"];
  if (all) args.push("--all");
  if (none) args.push("--none");
  for (var j = 0; j < paths.length; j += 1) args.push("--calendar", paths[j]);
  pushOptionalFlag(args, "--default", values.defaultRef);
  args.push("--output", "json");
  return args;
}

function syncRunAccountArgs(account) {
  return ["sync", "run", "--account", String((account || {}).id || ""), "--output", "json"];
}

function icalImportArgs(options) {
  var values = options || {};
  var args = ["ical", "import", String(values.path || "")];
  pushOptionalFlag(args, "--calendar", values.calendar);
  args.push("--output", "json");
  return args;
}

function showOpenInChroncalEnabled(settings) {
  return optionEnabled(settings, "showOpenInChroncal", false);
}

function eventNotesHtml(event, linkColor) {
  var text = event ? String(event.description || "") : "";
  if (text === "") return "";
  var email = eventJoinEmail(event);
  var color = htmlColor(linkColor);
  var pattern = /https?:\/\/[^\s<>()]+/ig;
  var html = "";
  var lastIndex = 0;
  var match;
  while ((match = pattern.exec(text)) !== null) {
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
  return values.join(" · ");
}

function humanRsvp(value) {
  var normalized = String(value || "").toLowerCase();
  return normalized === "" ? "No response" : normalized.charAt(0).toUpperCase() + normalized.slice(1);
}

function attendeeStatusLabel(attendee) {
  if (attendee && attendee.organizer === true) return "Organizer";
  return humanRsvp(attendee && attendee.rsvp_status);
}

function attendeeSummary(event) {
  var attendees = event && event.attendees ? event.attendees : [];
  return attendees.map(function(attendee) {
    var identity = String(attendee.name || attendee.email || "Guest");
    return identity + " · " + attendeeStatusLabel(attendee);
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
  if (event.description) lines.push(String(event.description));
  var attendees = event.attendees || [];
  attendees.forEach(function(attendee) {
    var identity = String(attendee.name || attendee.email || "Guest");
    var email = attendee.email && attendee.name ? " <" + attendee.email + ">" : "";
    lines.push(identity + email + " · " + attendeeStatusLabel(attendee));
  });
  if (event.url) lines.push(String(event.url));
  return lines.join("\n");
}
