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
      description: String(event.description || "")
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
    description: ""
  };
}

function validateEventForm(values) {
  var form = values || {};
  var errors = [];
  if (String(form.title || "").trim() === "") errors.push("Event title is required");
  if (!/^\d{4}-\d{2}-\d{2}$/.test(String(form.date || ""))) errors.push("Date must use YYYY-MM-DD");
  if (form.allDay !== true && !/^([01]\d|2[0-3]):[0-5]\d$/.test(String(form.time || ""))) errors.push("Time must use HH:MM");
  if (form.allDay !== true && !/^(?=.+)(?:\d+h)?(?:\d+m)?$/.test(String(form.duration || ""))) errors.push("Duration must look like 30m or 1h30m");
  return errors;
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
    return args;
  }

  args = ["event", "add", "--date", String(form.date)];
  pushOptionalFlag(args, "--calendar", form.calendar);
  if (form.allDay !== true) args.push("--time", String(form.time), "--duration", String(form.duration));
  pushOptionalFlag(args, "--location", form.location);
  pushOptionalFlag(args, "--description", form.description);
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

function firstUrlInText(value) {
  var match = String(value || "").match(/https?:\/\/[^\s<>()]+/i);
  return match ? match[0].replace(/[.,;:!?]+$/, "") : "";
}

function eventOpenUrl(event) {
  if (!event) return "";
  return String(event.conference_url || event.url || firstUrlInText(event.location) || firstUrlInText(event.description) || "");
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

function eventMailUrl(event) {
  var attendees = event && event.attendees ? event.attendees : [];
  var emails = attendees.map(function(attendee) { return String(attendee.email || ""); })
    .filter(function(email) { return email !== ""; });
  return emails.length === 0 ? "" : "mailto:" + encodeURIComponent(emails.join(","));
}

function humanRsvp(value) {
  var normalized = String(value || "").toLowerCase();
  return normalized === "" ? "No response" : normalized.charAt(0).toUpperCase() + normalized.slice(1);
}

function attendeeSummary(event) {
  var attendees = event && event.attendees ? event.attendees : [];
  return attendees.map(function(attendee) {
    var identity = String(attendee.name || attendee.email || "Guest");
    return identity + " · " + humanRsvp(attendee.rsvp_status);
  }).join("\n");
}

function eventDetailsText(event) {
  if (!event) return "";
  var lines = [String(event.title || "Untitled"), formatEventRange(event)];
  if (event.calendar_name) lines.push(String(event.calendar_name));
  if (event.location) lines.push(String(event.location));
  if (event.description) lines.push(String(event.description));
  var attendees = event.attendees || [];
  attendees.forEach(function(attendee) {
    var identity = String(attendee.name || attendee.email || "Guest");
    var email = attendee.email && attendee.name ? " <" + attendee.email + ">" : "";
    lines.push(identity + email + " · " + humanRsvp(attendee.rsvp_status));
  });
  if (event.url) lines.push(String(event.url));
  return lines.join("\n");
}
