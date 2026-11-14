// Behaviour that only shows west of Greenwich. Run with
// TZ=America/Sao_Paulo (UTC-3, no DST in 2026).
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import vm from "node:vm";

if (new Date("2026-11-13T12:00:00Z").getTimezoneOffset() !== 180) {
  console.error("run with TZ=America/Sao_Paulo");
  process.exit(2);
}

const source = readFileSync(new URL("../Model.js", import.meta.url), "utf8");
const model = { Date, Math, String, Number, Array, Object, Infinity };
vm.createContext(model);
vm.runInContext(source, model, { filename: "Model.js" });
const plain = value => JSON.parse(JSON.stringify(value));

// Friday 2026-11-13 21:18 local.
const now = "2026-11-14T00:18:00Z";
const holiday = { id: 1, title: "Republic Proclamation Day", all_day: true, start_time: "2026-11-15T00:00:00Z", end_time: "2026-11-16T00:00:00Z" };
const todayAllDay = { id: 2, title: "Friday off", all_day: true, start_time: "2026-11-13T00:00:00Z", end_time: "2026-11-14T00:00:00Z" };
const mondayClass = { id: 3, title: "Jiu-jitsu", all_day: false, start_time: "2026-11-16T09:30:00Z", end_time: "2026-11-16T10:30:00Z" };

// All-day dates are floating: Sunday's holiday is Sunday, not "Tomorrow".
const groups = model.groupEvents([mondayClass, holiday], now, { includeToday: true });
assert.deepEqual(plain(groups.map(group => [group.label, group.detail, group.events.map(event => event.id)])), [
  ["Today", "Fri, Nov 13", []],
  ["Sunday", "Sun, Nov 15", [1]],
  ["Monday", "Mon, Nov 16", [3]]
]);
assert.equal(model.formatEventDate(holiday, now), "Sunday, November 15");
assert.equal(model.eventDateKey(holiday), "2026-11-15");

// An all-day event lasts until local midnight, not 21:00 local.
assert.equal(model.activeEvents([todayAllDay], now).length, 1);
assert.equal(model.activeEvents([todayAllDay], "2026-11-14T03:00:01Z").length, 0);

// A multi-day event that started earlier is listed under Today.
const trip = { id: 4, title: "Trip", all_day: true, start_time: "2026-11-12T00:00:00Z", end_time: "2026-11-15T00:00:00Z" };
assert.equal(model.groupEvents([trip], now)[0].label, "Today");

// Keyboard order matches rendered order (all-day first within a day).
const sunday = { id: 5, title: "Brunch", all_day: false, start_time: "2026-11-15T02:30:00Z", end_time: "2026-11-15T03:30:00Z" };
assert.deepEqual(plain(model.agendaOrder(model.groupEvents([sunday, holiday], now)).map(event => event.id)), [5, 1]);
const sundayLater = { ...sunday, id: 6, start_time: "2026-11-15T13:00:00Z", end_time: "2026-11-15T14:00:00Z" };
assert.deepEqual(plain(model.agendaOrder(model.groupEvents([sundayLater, holiday], now)).map(event => event.id)), [1, 6]);

// Bar: the next timed meeting beats a future all-day event.
const bar = model.barPresentation({ status: "ok", generated_at: now, events: [holiday, mondayClass] }, 42, { now });
assert.equal(bar.event.id, 3);
assert.match(bar.text, /Mon 06:30 · Jiu-jitsu/);
// Only all-day events left: the future one is labelled with its day.
const onlyHoliday = model.barPresentation({ status: "ok", generated_at: now, events: [holiday] }, 42, { now });
assert.match(onlyHoliday.text, /Sun · Republic/);
const allDayToday = model.barPresentation({ status: "ok", generated_at: now, events: [todayAllDay, mondayClass] }, 42, { now });
assert.match(allDayToday.text, /All day · Friday off/);
// Bar horizon hides far-away events.
assert.equal(model.barPresentation({ status: "ok", generated_at: now, events: [mondayClass] }, 42, { now, barHorizonHours: 12 }).className, "empty");
// A stale agenda still counts down against the live clock.
const soon = { id: 7, title: "Sync", all_day: false, start_time: "2026-11-14T00:30:00Z", end_time: "2026-11-14T01:00:00Z" };
assert.match(model.barPresentation({ status: "ok", generated_at: now, events: [soon] }, 42, { now: "2026-11-14T00:22:00Z" }).text, /in 8m/);
// An ongoing meeting yields to the next one inside the countdown window.
const ongoing = { id: 8, title: "Long", all_day: false, start_time: "2026-11-14T00:00:00Z", end_time: "2026-11-14T01:00:00Z" };
assert.equal(model.barPresentation({ status: "ok", events: [ongoing, soon] }, 42, { now: "2026-11-14T00:10:00Z" }).event.id, 8);
const handoff = model.barPresentation({ status: "ok", events: [ongoing, soon] }, 42, { now: "2026-11-14T00:25:00Z" });
assert.equal(handoff.event.id, 7);
assert.match(handoff.text, /in 5m · Sync/);
// Declined invitations never reach the bar.
const me = "me@example.test";
const declined = { ...soon, id: 9, calendar_owner_email: me, attendees: [{ email: me, rsvp_status: "DECLINED" }] };
assert.equal(model.isDeclined(declined), true);
assert.equal(model.barPresentation({ status: "ok", events: [declined] }, 42, { now }).className, "empty");
assert.equal(model.filterEvents([declined], { showDeclinedEvents: "Off" }).length, 0);
assert.equal(model.filterEvents([declined], {}).length, 1);
const invited = { ...soon, id: 10, calendar_owner_email: me, attendees: [{ email: me, rsvp_status: "NEEDS-ACTION" }] };
assert.equal(model.awaitingResponse(invited), true);
assert.match(model.eventRowSubtitle(invited), /Invited/);

// Conferencing: the Meet link wins over earlier non-meeting URLs.
const meeting = {
  calendar_owner_email: me,
  description: "Agenda https://docs.example.test/doc\n-::~:~::~:~::-\nJoin with Google Meet: https://meet.google.com/abc-defg-hij\nOr dial: https://tel.meet/abc?pin=1\n-::~:~::~:~::-"
};
assert.equal(model.eventConferenceUrl(meeting), "https://meet.google.com/abc-defg-hij?authuser=me%40example.test");
assert.equal(model.eventOpenUrl(meeting), "https://meet.google.com/abc-defg-hij?authuser=me%40example.test");
assert.equal(model.eventJoinLabel(meeting), "Join Google Meet");
assert.equal(model.eventJoinLabel({ location: "https://us02web.zoom.us/j/123?pwd=x" }), "Join Zoom");
assert.equal(model.eventJoinLabel({ description: "See https://docs.example.test/doc" }), "Open link");
assert.equal(model.eventJoinLabel({}), "");
assert.equal(model.conferenceProvider("https://teams.microsoft.com/l/meetup-join/1"), "Teams");
assert.equal(model.conferenceProvider("https://evilzoom.us/j/1"), "");
// The invitation boilerplate is hidden from notes.
assert.equal(model.cleanDescription(meeting.description), "Agenda https://docs.example.test/doc");
assert.equal(model.cleanDescription("Hi\n________________________________________________________________________________\nMicrosoft Teams meeting\nJoin: https://teams.microsoft.com/l/x\n________________________________________________________________________________"), "Hi");
assert.doesNotMatch(model.eventNotesHtml(meeting), /tel\.meet/);
assert.match(model.eventDetailsText({ ...meeting, title: "Sync", start_time: soon.start_time, end_time: soon.end_time }, now), /meet\.google\.com/);

// Join-next picks the ongoing call, else today's next call.
const call = { ...soon, id: 11, description: meeting.description };
assert.equal(model.joinableEvent([mondayClass, call], now).id, 11);
assert.equal(model.joinableEvent([{ ...mondayClass, description: meeting.description }], now), null);

// Read-only subscriptions cannot be edited, deleted, or answered.
const readOnly = { id: 12, uid: "h", calendar_read_only: true, calendar_owner_email: me, attendees: [{ email: me }] };
assert.equal(model.canEditEvent(readOnly), false);
assert.equal(model.canDeleteEvent(readOnly), false);
assert.equal(model.canRsvp(readOnly), false);
assert.deepEqual(plain(model.calendarNameOptions([{ name: "Work" }, { name: "Holidays", read_only: true }, { name: "Work" }])), [{ value: "Work", label: "Work" }]);

// Events in the local zone can move; other zones still cannot.
const zoned = { id: 13, title: "Standup", start_time: "2026-11-16T12:00:00Z", end_time: "2026-11-16T12:30:00Z", all_day: false, timezone: "America/Sao_Paulo" };
const values = { ...model.eventEditorValues(zoned), time: "10:00" };
assert.deepEqual(plain(model.eventMutationArgs("edit", zoned, values, { localTimezone: "America/Sao_Paulo" })), ["event", "update", "13", "--title", "Standup", "--time", "10:00"]);
assert.deepEqual(plain(model.eventMutationArgs("edit", { ...zoned, timezone: "Europe/Lisbon" }, values, { localTimezone: "America/Sao_Paulo" })), []);
assert.equal(model.canEditEventTime(zoned, ""), false);

// Reminders fire once, inside the lead window, never for long-running calls.
const due = model.dueReminders([soon, ongoing, declined, holiday], "2026-11-14T00:29:30Z", 1, {});
assert.deepEqual(plain(due.map(event => event.id)), [7]);
assert.equal(model.dueReminders([soon], "2026-11-14T00:29:30Z", 1, { [model.eventKey(soon)]: soon.end_time }).length, 0);
assert.equal(model.dueReminders([soon], "2026-11-14T00:33:00Z", 1, {}).length, 0);
assert.deepEqual(plain(model.pruneReminderKeys({ a: "2026-11-14T00:00:00Z", b: "2026-11-14T02:00:00Z" }, now)), { b: "2026-11-14T02:00:00Z" });
assert.match(model.reminderBody(soon, "2026-11-14T00:29:30Z"), /^Starts in 1m · 21:30–22:00/);

// Row status and guest counts.
assert.equal(model.eventRowStatus(soon, "2026-11-14T00:10:00Z"), "in 20m");
assert.equal(model.eventRowStatus(ongoing, "2026-11-14T00:10:00Z"), "50m left");
assert.equal(model.eventRowStatus(mondayClass, now), "");
const guests = { calendar_owner_email: me, attendees: [
  { name: "org@example.test", email: "org@example.test", organizer: true, rsvp_status: "ACCEPTED" },
  { email: "a@example.test", rsvp_status: "ACCEPTED" },
  { name: "Bea", email: "b@example.test", rsvp_status: "DECLINED" },
  { email: me, rsvp_status: "NEEDS-ACTION" }
] };
assert.equal(model.attendeeCountsLabel(guests), "4 guests · 2 yes · 1 no · 1 awaiting");
assert.equal(model.organizerLabel(guests), "org@example.test");
assert.equal(model.attendeeSummary(guests).split("\n")[0], "org@example.test · Organizer");

console.log("local-timezone model tests: ok");
