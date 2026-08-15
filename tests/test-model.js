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
  "event", "add", "Review launch", "--date", "2026-08-18", "--calendar", "Work",
  "--time", "14:30", "--duration", "45m", "--location", "Room 4", "--description", "Decide launch date"
]);
assert.deepEqual(model.eventMutationArgs("edit", { id: 42, all_day: false }, createValues).slice(0, 5), [
  "event", "update", "42", "--title", "Review launch"
]);
assert.deepEqual(model.eventDeleteArgs({ id: 42 }), ["event", "delete", "42", "--yes"]);
assert.deepEqual(model.eventDeleteArgs({ id: 42, uid: "weekly-uid", recurrence_id: "2026-08-18T14:30:00Z" }), [
  "event", "delete", "weekly-uid", "--recurrence-id", "2026-08-18T14:30:00Z", "--yes"
]);
assert.match(model.validateEventForm({ ...createValues, title: "" })[0], /title/i);
assert.match(model.validateEventForm({ ...createValues, duration: "" })[0], /duration/i);
const clearOptionalArgs = model.eventMutationArgs("edit", { id: 42, all_day: false }, { ...createValues, location: "", description: "" });
assert.deepEqual(clearOptionalArgs.slice(-4), ["--location", "", "--description", ""]);

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
