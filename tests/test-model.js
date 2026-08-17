import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import vm from "node:vm";

const source = readFileSync(new URL("../Model.js", import.meta.url), "utf8");
const model = { Date, Math, String, Number, Array, Object };
vm.createContext(model);
vm.runInContext(source, model, { filename: "Model.js" });

const events = [
  {
    id: 1,
    title: "Current",
    start_time: "2026-08-15T11:30:00Z",
    end_time: "2026-08-15T12:30:00Z",
    all_day: false
  },
  {
    id: 2,
    title: "Tomorrow",
    start_time: "2026-08-16T09:00:00Z",
    end_time: "2026-08-16T10:15:00Z",
    all_day: false
  },
  {
    id: 3,
    title: "All day",
    start_time: "2026-08-16T00:00:00Z",
    end_time: "2026-08-17T00:00:00Z",
    all_day: true
  }
];

const groups = model.groupEvents(events, "2026-08-15T12:00:00Z");
assert.deepEqual(
  JSON.parse(JSON.stringify(groups.map(group => ({ label: group.label, ids: group.events.map(event => event.id) })))),
  [
    { label: "Today", ids: [1] },
    { label: "Tomorrow", ids: [3, 2] }
  ]
);
assert.equal(model.formatEventRange(events[0]), "11:30–12:30");
assert.equal(model.formatEventRange(events[2]), "All day");
assert.equal(model.eventProgress(events[0], "2026-08-15T12:00:00Z"), 0.5);
assert.equal(model.eventProgress(events[1], "2026-08-15T12:00:00Z"), 0);
assert.equal(model.clampSelection(-1, 3), 0);
assert.equal(model.clampSelection(4, 3), 2);
assert.equal(model.clampSelection(0, 0), -1);
assert.equal(model.firstEventIndexForDate(events, "2026-08-15T12:00:00Z"), 0);
assert.equal(model.firstEventIndexForDate(events.slice(1), "2026-08-15T12:00:00Z"), -1);
const dayEvents = [
  { id: 10, start_time: "2026-08-16T09:00:00Z" },
  { id: 11, start_time: "2026-08-16T15:00:00Z" },
  { id: 12, start_time: "2026-08-17T08:00:00Z" },
  { id: 13, start_time: "2026-08-19T10:00:00Z" }
];
assert.equal(model.eventDateKey(dayEvents[0]), "2026-08-16");
assert.equal(model.firstEventIndexForDay(dayEvents, "2026-08-17"), 2);
assert.equal(model.firstEventIndexForDay(dayEvents, "2026-08-18"), -1);
assert.equal(model.adjacentDayFirstEventIndex(dayEvents, 0, 1), 2);
assert.equal(model.adjacentDayFirstEventIndex(dayEvents, 1, 1), 2);
assert.equal(model.adjacentDayFirstEventIndex(dayEvents, 2, 1), 3);
assert.equal(model.adjacentDayFirstEventIndex(dayEvents, 3, 1), -1);
assert.equal(model.adjacentDayFirstEventIndex(dayEvents, 3, -1), 2);
assert.equal(model.adjacentDayFirstEventIndex(dayEvents, 2, -1), 0);
assert.equal(model.adjacentDayFirstEventIndex(dayEvents, 0, -1), -1);
assert.equal(model.adjacentDayFirstEventIndex([], 0, 1), -1);

const detailedEvent = {
  ...events[0],
  description: "Discuss launch plan",
  location: "Rua Exemplo 10, Curitiba",
  conference_url: "https://meet.example.test/room",
  url: "https://calendar.example.test/event/1",
  attendees: [
    { name: "Alice", email: "alice@example.test", rsvp_status: "ACCEPTED" },
    { name: "Bob", email: "bob@example.test", rsvp_status: "TENTATIVE" }
  ]
};
assert.equal(model.eventOpenUrl(detailedEvent), "https://meet.example.test/room");
assert.equal(model.eventOpenUrl({ location: "Join at https://meet.example.test/from-location", description: "Fallback https://notes.example.test" }), "https://meet.example.test/from-location");
assert.equal(model.eventOpenUrl({ description: "Notes: https://notes.example.test/doc." }), "https://notes.example.test/doc");
assert.match(model.eventAttributes({ status: "CONFIRMED", class: "PRIVATE", transp: "TRANSPARENT", recurrence_rule: "FREQ=WEEKLY" }), /Confirmed · Private · Free · Recurring/);
assert.equal(model.eventMapUrl(detailedEvent), "https://www.google.com/maps/search/?api=1&query=Rua%20Exemplo%2010%2C%20Curitiba");
assert.equal(model.eventMailUrl(detailedEvent), "mailto:alice%40example.test%2Cbob%40example.test");
assert.deepEqual(model.searchEvents([detailedEvent, events[1]], "launch").map(event => event.id), [1]);
assert.deepEqual(model.searchEvents([detailedEvent, events[1]], "alice").map(event => event.id), [1]);
assert.deepEqual(model.searchEvents([{ ...detailedEvent, calendar_name: "Work" }, events[1]], "work").map(event => event.id), [1]);
assert.deepEqual(model.searchEvents([detailedEvent, events[1]], "  ").map(event => event.id), [1, 2]);
assert.match(model.attendeeSummary(detailedEvent), /Alice · Accepted/);
assert.match(model.eventDetailsText(detailedEvent), /Current/);
assert.match(model.eventDetailsText(detailedEvent), /Discuss launch plan/);
assert.match(model.eventDetailsText(detailedEvent), /alice@example.test/);

const createValues = {
  title: "Review launch",
  date: "2026-08-18",
  time: "14:30",
  duration: "45m",
  allDay: false,
  calendar: "Work",
  location: "Room 4",
  description: "Decide launch date"
};
assert.deepEqual(model.validateEventForm(createValues), []);
assert.deepEqual(model.eventMutationArgs("create", null, createValues), [
  "event", "add", "--date", "2026-08-18", "--calendar", "Work",
  "--time", "14:30", "--duration", "45m", "--location", "Room 4", "--description", "Decide launch date",
  "--", "Review launch"
]);
const existingEditEvent = {
  id: 42,
  uid: "single-uid",
  title: "Review launch",
  start_time: "2026-08-18T14:30:00Z",
  end_time: "2026-08-18T15:15:00Z",
  all_day: false,
  timezone: "America/New_York",
  calendar_name: "Work",
  location: "Room 4",
  description: "Decide launch date"
};
const unchangedEditArgs = model.eventMutationArgs("edit", existingEditEvent, createValues);
assert.deepEqual(unchangedEditArgs, ["event", "update", "42", "--title", "Review launch"]);
assert.deepEqual(model.eventMutationArgs("edit", existingEditEvent, { ...createValues, time: "15:30" }), []);
assert.deepEqual(model.eventDeleteArgs({ id: 42 }), ["event", "delete", "42", "--yes"]);
assert.deepEqual(model.eventDeleteArgs({ id: 42, uid: "weekly-uid", recurrence_id: "2026-08-18T14:30:00Z" }), [
  "event", "delete", "weekly-uid", "--recurrence-id", "2026-08-18T14:30:00Z", "--yes"
]);
assert.equal(model.canMutateEvent({ id: 42, recurrence_rule: "FREQ=WEEKLY", recurrence_id: "" }), false);
assert.equal(model.canMutateEvent({ id: 42, rdates: "2026-08-18T14:30:00Z", recurrence_id: "" }), false);
assert.equal(model.canMutateEvent({ id: 42, recurrence_rule: "FREQ=WEEKLY", recurrence_id: "2026-08-18T14:30:00Z" }), true);
assert.equal(model.canMutateEvent({ id: 42, recurrence_rule: "" }), true);
assert.deepEqual(model.eventMutationArgs("edit", { id: 42, recurrence_rule: "FREQ=WEEKLY" }, createValues), []);
assert.deepEqual(model.eventDeleteArgs({ id: 42, recurrence_rule: "FREQ=WEEKLY" }), []);
assert.match(model.validateEventForm({ ...createValues, title: "" })[0], /title/i);
assert.match(model.validateEventForm({ ...createValues, duration: "" })[0], /duration/i);
const clearOptionalArgs = model.eventMutationArgs("edit", { ...existingEditEvent, location: "Old room", description: "Old notes" }, { ...createValues, location: "", description: "" });
assert.deepEqual(clearOptionalArgs.slice(-4), ["--location", "", "--description", ""]);
assert.notEqual(model.eventKey({ id: 42, uid: "weekly", start_time: "2026-08-18T14:30:00Z" }), model.eventKey({ id: 42, uid: "weekly", start_time: "2026-08-25T14:30:00Z" }));

assert.equal(model.parseDateInput(""), null);
assert.equal(model.parseDateInput("2026-8-18"), null);
assert.equal(model.parseDateInput("2026-02-29"), null);
assert.equal(model.parseDateInput("2026-13-01"), null);
const parsedDate = model.parseDateInput("2026-08-18");
assert.equal(parsedDate.getFullYear(), 2026);
assert.equal(parsedDate.getMonth(), 7);
assert.equal(parsedDate.getDate(), 18);
assert.equal(model.formatDateInput(parsedDate), "2026-08-18");
assert.deepEqual(model.stepMonth(2026, 11, 1), { year: 2027, month: 0 });
assert.deepEqual(model.stepMonth(2026, 0, -1), { year: 2025, month: 11 });
assert.equal(model.shiftDateInput("2026-08-31", 1), "2026-09-01");
assert.equal(model.shiftDateInput("bad", 1), "");
assert.deepEqual(model.weekdayOrder(1), [1, 2, 3, 4, 5, 6, 0]);
const augustGrid = model.monthGrid(2026, 7, 1, "2026-08-16", "2026-08-18");
assert.equal(augustGrid.length, 6);
assert.equal(augustGrid[0][0].key, "2026-07-27");
assert.equal(augustGrid[0][0].inMonth, false);
assert.equal(augustGrid[0][5].key, "2026-08-01");
assert.equal(augustGrid[0][5].inMonth, true);
assert.equal(augustGrid[2][6].key, "2026-08-16");
assert.equal(augustGrid[2][6].today, true);
assert.equal(augustGrid[3][1].key, "2026-08-18");
assert.equal(augustGrid[3][1].selected, true);

assert.equal(model.eventReference(null), "");
assert.equal(model.eventReference({}), "");
assert.equal(model.eventReference({ id: "", uid: "" }), "");
assert.equal(model.eventReference({ uid: "weekly-uid" }), "weekly-uid");
assert.equal(model.eventReference({ id: 42, uid: "weekly-uid" }), "42");
assert.equal(model.eventReference({ id: 0 }), "0");
assert.equal(model.canEditEvent({ id: 0 }), true);
assert.equal(model.canEditEvent(null), false);
assert.equal(model.canEditEvent({}), false);
assert.equal(model.canEditEvent({ id: 42 }), true);
assert.equal(model.canEditEvent({ uid: "weekly-uid" }), true);
assert.equal(model.isGeneratedRecurringEvent(null), false);
assert.equal(model.isGeneratedRecurringEvent({ id: 42, recurrence_rule: "" }), false);
assert.equal(model.isGeneratedRecurringEvent({ id: 42, recurrence_rule: "FREQ=WEEKLY" }), true);
assert.equal(model.isGeneratedRecurringEvent({ id: 42, rdates: "2026-08-18T14:30:00Z" }), true);
assert.equal(model.isGeneratedRecurringEvent({ id: 42, uid: "weekly-uid", recurrence_rule: "FREQ=WEEKLY", recurrence_id: "2026-08-18T14:30:00Z" }), false);
assert.equal(model.canMutateEvent({ recurrence_rule: "FREQ=WEEKLY", recurrence_id: "2026-08-18T14:30:00Z" }), false);
assert.deepEqual(model.eventDeleteArgs({}), []);
assert.deepEqual(model.seriesMasterLookupArgs({ id: 42, recurrence_rule: "FREQ=WEEKLY" }), ["event", "get", "42", "--output", "json"]);
assert.deepEqual(model.seriesMasterLookupArgs({ uid: "weekly-uid", rdates: "2026-08-18T14:30:00Z" }), ["event", "get", "weekly-uid", "--output", "json"]);
assert.deepEqual(model.seriesMasterLookupArgs({ id: 42, uid: "weekly-uid", recurrence_rule: "FREQ=WEEKLY", recurrence_id: "2026-08-18T14:30:00Z" }), []);
assert.deepEqual(model.seriesMasterLookupArgs({ id: 42, recurrence_rule: "" }), []);
assert.deepEqual(model.seriesMasterLookupArgs({ recurrence_rule: "FREQ=WEEKLY" }), []);

const generatedOccurrence = {
  id: 42,
  uid: "weekly-uid",
  title: "Review launch",
  start_time: "2026-08-25T14:30:00Z",
  end_time: "2026-08-25T15:15:00Z",
  all_day: false,
  recurrence_rule: "FREQ=WEEKLY",
  calendar_id: 3,
  calendar_name: "Work",
  calendar_color: "#ff0000",
  calendar_owner_email: "owner@example.test"
};
const loadedSeriesMaster = {
  id: 42,
  uid: "weekly-uid",
  title: "Review launch",
  start_time: "2026-08-18T14:30:00Z",
  end_time: "2026-08-18T15:15:00Z",
  all_day: false,
  recurrence_rule: "FREQ=WEEKLY",
  calendar_name: "Team",
  calendar_color: "#00ff00",
  calendar_owner_email: null
};
const mergedSeriesMaster = model.seriesEditorEvent(loadedSeriesMaster, generatedOccurrence);
assert.notEqual(mergedSeriesMaster, loadedSeriesMaster);
assert.equal(mergedSeriesMaster.start_time, "2026-08-18T14:30:00Z");
assert.equal(mergedSeriesMaster.end_time, "2026-08-18T15:15:00Z");
assert.equal(mergedSeriesMaster.recurrence_rule, "FREQ=WEEKLY");
assert.equal(mergedSeriesMaster.calendar_name, "Team");
assert.equal(mergedSeriesMaster.calendar_color, "#00ff00");
assert.equal(mergedSeriesMaster.calendar_id, 3);
assert.equal(mergedSeriesMaster.calendar_owner_email, "owner@example.test");
const idOnlySeriesMaster = model.seriesEditorEvent({ id: 42, recurrence_rule: "FREQ=WEEKLY" }, generatedOccurrence);
assert.equal(idOnlySeriesMaster.calendar_name, "Work");
assert.notEqual(model.seriesEditorEvent({ id: "42", recurrence_rule: "FREQ=WEEKLY" }, generatedOccurrence), null);
assert.equal(model.seriesEditorEvent({ id: 43, uid: "weekly-uid", recurrence_rule: "FREQ=WEEKLY" }, generatedOccurrence), null);
assert.equal(model.seriesEditorEvent({ id: 42, uid: "other-uid", recurrence_rule: "FREQ=WEEKLY" }, generatedOccurrence), null);
assert.equal(model.seriesEditorEvent({ recurrence_rule: "FREQ=WEEKLY" }, generatedOccurrence), null);
assert.equal(model.seriesEditorEvent({ id: 42, uid: "weekly-uid" }, generatedOccurrence), null);
assert.equal(model.seriesEditorEvent(loadedSeriesMaster, { id: 42, uid: "weekly-uid", recurrence_rule: "FREQ=WEEKLY", recurrence_id: "2026-08-25T14:30:00Z" }), null);
assert.equal(model.seriesEditorEvent(null, generatedOccurrence), null);
const seriesEditValues = { ...createValues, calendar: "Team" };
const seriesUpdateArgs = model.eventMutationArgs("edit", mergedSeriesMaster, seriesEditValues, { series: true });
assert.deepEqual(seriesUpdateArgs.slice(0, 4), ["event", "update", "42", "--title"]);
assert.deepEqual(seriesUpdateArgs.slice(-4), ["--location", "Room 4", "--description", "Decide launch date"]);
assert.deepEqual(model.eventMutationArgs("edit", mergedSeriesMaster, seriesEditValues), []);
assert.deepEqual(model.eventMutationArgs("edit", mergedSeriesMaster, seriesEditValues, { series: false }), []);
assert.deepEqual(model.eventMutationArgs("edit", { recurrence_rule: "FREQ=WEEKLY" }, seriesEditValues, { series: true }), []);
assert.deepEqual(model.eventMutationTargetArgs({ id: 0, recurrence_rule: "FREQ=WEEKLY" }), ["0"]);
assert.deepEqual(model.eventMutationTargetArgs({ id: 0 }), ["0"]);
assert.deepEqual(model.eventMutationTargetArgs({ id: 0, uid: "weekly-uid", recurrence_id: "2026-08-18T14:30:00Z" }), ["weekly-uid", "--recurrence-id", "2026-08-18T14:30:00Z"]);
const zeroIdSeriesArgs = model.eventMutationArgs("edit", { id: 0, recurrence_rule: "FREQ=WEEKLY" }, createValues, { series: true });
assert.deepEqual(zeroIdSeriesArgs.slice(0, 3), ["event", "update", "0"]);
assert.deepEqual(model.eventMutationArgs("edit", { id: 0, recurrence_rule: "FREQ=WEEKLY" }, createValues), []);
assert.deepEqual(model.eventDeleteArgs({ id: 0 }), ["event", "delete", "0", "--yes"]);
assert.deepEqual(model.eventMutationArgs("edit", existingEditEvent, createValues, { series: true }), ["event", "update", "42", "--title", "Review launch"]);
assert.deepEqual(model.eventMutationArgs("create", null, createValues, { series: true }), model.eventMutationArgs("create", null, createValues));
assert.deepEqual(model.eventDeleteArgs(mergedSeriesMaster), []);
const overrideEditEvent = { ...existingEditEvent, uid: "weekly-uid", recurrence_id: "2026-08-18T14:30:00Z" };
assert.deepEqual(model.eventMutationArgs("edit", overrideEditEvent, createValues), ["event", "update", "weekly-uid", "--recurrence-id", "2026-08-18T14:30:00Z", "--title", "Review launch"]);
assert.equal(model.isRecurringEvent({ id: 42 }), false);
assert.equal(model.isRecurringEvent(generatedOccurrence), true);
assert.equal(model.isRecurringEvent({ id: 42, rdates: "2026-08-18T14:30:00Z" }), true);
assert.equal(model.isRecurringEvent(overrideEditEvent), true);
assert.equal(model.canDeleteEvent(generatedOccurrence), true);
assert.equal(model.canDeleteEvent({}), false);
assert.equal(model.eventOccurrenceStamp(generatedOccurrence), "2026-08-25T14:30:00Z");
assert.equal(model.eventOccurrenceStamp(overrideEditEvent), "2026-08-18T14:30:00Z");
assert.deepEqual(model.eventDeleteArgs(generatedOccurrence), []);
assert.deepEqual(model.eventDeleteArgs(generatedOccurrence, { series: true }), ["event", "delete", "weekly-uid", "--series", "--yes"]);
assert.deepEqual(model.eventDeleteArgs({ id: 42, recurrence_rule: "FREQ=WEEKLY" }, { series: true }), ["event", "delete", "42", "--series", "--yes"]);
assert.deepEqual(model.eventDeleteArgs(overrideEditEvent, { series: true }), ["event", "delete", "weekly-uid", "--series", "--yes"]);
assert.deepEqual(model.eventDeleteArgs(generatedOccurrence, { thisEvent: true }), [
  "event", "delete", "weekly-uid", "--recurrence-id", "2026-08-25T14:30:00Z", "--yes"
]);
assert.deepEqual(model.eventDeleteArgs(generatedOccurrence, { following: true }), [
  "event", "delete", "weekly-uid", "--following", "2026-08-25T14:30:00Z", "--yes"
]);
assert.deepEqual(model.eventDeleteArgs(overrideEditEvent, { thisEvent: true }), [
  "event", "delete", "weekly-uid", "--recurrence-id", "2026-08-18T14:30:00Z", "--yes"
]);
assert.deepEqual(model.eventDeleteArgs(overrideEditEvent, { following: true }), [
  "event", "delete", "weekly-uid", "--following", "2026-08-18T14:30:00Z", "--yes"
]);
assert.deepEqual(model.eventDeleteArgs(generatedOccurrence, { series: true, thisEvent: true }), []);
assert.deepEqual(model.eventDeleteArgs(generatedOccurrence, { thisEvent: true, following: true }), []);
assert.deepEqual(model.eventDeleteArgs({ id: 42, recurrence_rule: "FREQ=WEEKLY", start_time: "" }, { thisEvent: true }), []);

const filterEvents = [
  { ...detailedEvent, id: 21, calendar_id: 1, all_day: false },
  { ...events[2], id: 22, calendar_id: 2, all_day: true, attendees: [], location: "", conference_url: "", url: "" },
  { ...events[1], id: 23, calendar_id: 3, all_day: false, attendees: [], location: "", conference_url: "", url: "" }
];
assert.deepEqual(model.filterEvents(filterEvents, { includedCalendarIds: ["1"] }).map(event => event.id), [21]);
assert.deepEqual(model.filterEvents(filterEvents, { showAllDay: false }).map(event => event.id), [21, 23]);
assert.deepEqual(model.filterEvents(filterEvents, { showEventsWithoutParticipants: false }).map(event => event.id), [21]);
assert.deepEqual(model.filterEvents(filterEvents, { showEventsWithoutLocation: false }).map(event => event.id), [21]);
const filteredAgenda = model.filterAgenda({ status: "ok", events: filterEvents, next: filterEvents[0] }, { includedCalendarIds: ["3"] });
assert.equal(filteredAgenda.next.id, 23);
assert.deepEqual(model.calendarOptions([{ id: 2, name: "Work" }, { id: 1, name: "Personal" }]), [
  { value: "1", label: "Personal", description: "" },
  { value: "2", label: "Work", description: "" }
]);
const calendarSelectionCalendars = [
  { id: 1, name: "Personal" },
  { id: 2, name: "Work" },
  { id: 3, name: "Family" }
];
assert.equal(model.calendarSelectionCustomized({}), false);
assert.equal(model.calendarSelectionCustomized({ includedCalendarIds: [] }), false);
assert.equal(model.calendarSelectionCustomized({ includedCalendarIds: ["2"] }), true);
assert.equal(model.calendarSelectionCustomized({ includedCalendarIds: [], calendarSelectionCustomized: true }), true);
assert.deepEqual(model.selectedCalendarIds(calendarSelectionCalendars, {}), ["1", "2", "3"]);
assert.deepEqual(model.selectedCalendarIds(calendarSelectionCalendars, { includedCalendarIds: ["2"] }), ["2"]);
assert.deepEqual(model.selectedCalendarIds(calendarSelectionCalendars, { includedCalendarIds: [], calendarSelectionCustomized: true }), []);
assert.deepEqual(model.filterEvents(filterEvents, { includedCalendarIds: [], calendarSelectionCustomized: false }).map(event => event.id), [21, 22, 23]);
assert.deepEqual(model.filterEvents(filterEvents, { includedCalendarIds: [], calendarSelectionCustomized: true }).map(event => event.id), []);

const presentation = model.barPresentation({
  status: "ok",
  generated_at: "2026-08-15T12:00:00Z",
  events: [
    { ...events[0], calendar_color: "#ff3366" },
    {
      id: 4,
      title: "Pairing",
      start_time: "2026-08-15T12:00:00Z",
      end_time: "2026-08-15T13:00:00Z",
      all_day: false,
      calendar_color: "#3366ff"
    }
  ]
}, 42);
assert.deepEqual(JSON.parse(JSON.stringify(presentation.className)), ["in-progress", "overlap"]);
assert.match(presentation.text, /Current/);
assert.match(presentation.text, /Pairing/);
assert.match(presentation.tooltip, /11:30–12:30/);
assert.equal(model.barPresentation({ status: "unavailable", events: [] }, 42).className, "unavailable");
assert.equal(model.barPresentation({ status: "ok", generated_at: "2026-08-15T12:00:00Z", events: [] }, 42).className, "empty");

const futurePresentation = model.barPresentation({
  status: "ok",
  generated_at: "2026-08-15T12:00:00Z",
  events: [{ ...events[0], title: "Monday planning", start_time: "2026-08-17T09:00:00Z", end_time: "2026-08-17T10:00:00Z" }]
}, 42);
assert.match(futurePresentation.text, /Mon 09:00/);
const countdownPresentation = model.barPresentation({
  status: "ok",
  generated_at: "2026-08-15T12:00:00Z",
  events: [{ ...events[0], title: "Soon", start_time: "2026-08-15T12:20:00Z", end_time: "2026-08-15T13:20:00Z" }]
}, 42, { relativeLeadMinutes: 30 });
assert.match(countdownPresentation.text, /in 20m/);

const titleOnly = model.barPresentation({
  status: "ok",
  generated_at: "2026-08-15T12:00:00Z",
  events: [{ ...events[0], calendar_color: "#ff3366" }]
}, 42, { showTime: false, showTitle: true });
assert.match(titleOnly.text, /Current/);
assert.doesNotMatch(titleOnly.text, /left|Now|in [0-9]/);
const timeOnly = model.barPresentation({
  status: "ok",
  generated_at: "2026-08-15T12:00:00Z",
  events: [{ ...events[0], calendar_color: "#ff3366" }]
}, 42, { showTime: true, showTitle: false });
assert.doesNotMatch(timeOnly.text, /Current/);
assert.match(timeOnly.text, /left|Now/);

console.log("agenda model tests: ok");
