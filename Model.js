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

function eventLeadLabel(event, now) {
  var start = parseDate(event.start_time);
  var end = parseDate(event.end_time);
  if (!start || !end) return "";
  var untilStart = (start.getTime() - now.getTime()) / 1000;
  if (untilStart > 0) {
    var dayLabel = relativeDayLabel(start, now);
    if (dayLabel !== "") return dayLabel + " " + formatTime(event.start_time);
    return untilStart <= 600 ? "in " + durationLabel(untilStart) : formatTime(event.start_time);
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

function filterEvents(events, options) {
  var source = events || [];
  var included = arrayValues(options && options.includedCalendarIds).map(function(value) { return String(value); });
  var showAllDay = optionEnabled(options, "showAllDay", true);
  var showWithoutParticipants = optionEnabled(options, "showEventsWithoutParticipants", true);
  var showWithoutLocation = optionEnabled(options, "showEventsWithoutLocation", true);

  return source.filter(function(event) {
    if (included.length > 0 && included.indexOf(String(event.calendar_id)) === -1) return false;
    if (!showAllDay && event.all_day === true) return false;
    if (!showWithoutParticipants && (!event.attendees || event.attendees.length === 0)) return false;
    if (!showWithoutLocation && !event.location && !event.conference_url) return false;
    return true;
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
    if (showTime) parts.push(eventLeadLabel(anchor, now));
    if (showTitle) parts.push(escapeHtml(truncate(anchor.title, titleLimit)));
    return {
      text: parts.length > 0 ? richText(" " + parts.join(" · ") + " ") : "",
      className: className,
      tooltip: tooltip
    };
  }

  var visible = cluster.slice(0, 3).map(function(event) {
    var eventParts = [];
    if (showTime) eventParts.push(eventLeadLabel(event, now));
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

function eventOpenUrl(event) {
  if (!event) return "";
  return String(event.conference_url || event.url || "");
}

function eventMapUrl(event) {
  var location = event ? String(event.location || "") : "";
  return location === "" ? "" : "https://www.google.com/maps/search/?api=1&query=" + encodeURIComponent(location);
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
