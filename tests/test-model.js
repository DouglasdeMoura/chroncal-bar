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

console.log("agenda model tests: ok");
