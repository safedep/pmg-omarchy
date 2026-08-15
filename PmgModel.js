.pragma library

// PmgModel is the pure logic core. It turns PMG event-log lines into the shapes
// the QML binds to. It has no framework code, so plain JS tests cover it
// (test/model.test.mjs).

// Map each verdict to a display severity: block (red), hold (amber),
// allow (green), info (muted).
var SEVERITY = {
    malware_blocked: "block",
    malware_confirmed: "block",
    install_insecure_bypass: "block",
    dependency_cooldown: "hold",
    install_allowed: "allow",
    install_trusted_allowed: "allow",
    sandbox_override: "info",
};

var LABEL = {
    malware_blocked: "blocked",
    malware_confirmed: "allowed by user",
    install_insecure_bypass: "insecure bypass",
    dependency_cooldown: "cooldown hold",
    install_allowed: "allowed",
    install_trusted_allowed: "trusted",
    sandbox_override: "sandbox override",
};

// True for events the feed shows. Lifecycle and bookkeeping events are excluded.
function isDisplayable(ev) {
    return !!ev && SEVERITY.hasOwnProperty(ev.event_type);
}

// True only for a real block. malware_confirmed is a user override, not a block.
function isBlock(ev) {
    return !!ev && ev.event_type === "malware_blocked";
}

function severityOf(ev) {
    return (ev && SEVERITY[ev.event_type]) || "info";
}

function labelOf(ev) {
    return (ev && LABEL[ev.event_type]) || (ev ? ev.event_type : "");
}

// Parse one JSONL line to an event, or null for a blank or bad line.
function parseLine(line) {
    var trimmed = String(line || "").trim();
    if (!trimmed) return null;
    try {
        var ev = JSON.parse(trimmed);
        return ev && typeof ev === "object" ? ev : null;
    } catch (e) {
        return null;
    }
}

// parseLog parses a whole log file body into events, oldest-first as written.
function parseLog(text) {
    var out = [];
    var lines = String(text || "").split("\n");
    for (var i = 0; i < lines.length; i++) {
        var ev = parseLine(lines[i]);
        if (ev) out.push(ev);
    }
    return out;
}

function timestampMillis(ev) {
    if (!ev || !ev.timestamp) return 0;
    var t = Date.parse(ev.timestamp);
    return isNaN(t) ? 0 : t;
}

// Turn the proto enum ecosystem into a label, so ECOSYSTEM_PYPI becomes pypi.
// Unspecified or unknown becomes "" so the UI shows nothing.
function humanizeEcosystem(eco) {
    var s = String(eco || "").replace(/^ECOSYSTEM_/i, "").toLowerCase();
    if (s === "unspecified" || s === "unknown") return "";
    return s;
}

// feedRows projects displayable events into newest-first view rows. It collapses
// consecutive identical rows into one row with a count, then caps the result.
function feedRows(events, limit, nowMillis) {
    var rows = [];
    for (var i = 0; i < events.length; i++) {
        var ev = events[i];
        if (!isDisplayable(ev)) continue;
        rows.push({
            severity: severityOf(ev),
            verdict: labelOf(ev),
            ecosystem: humanizeEcosystem(ev.ecosystem),
            pkg: ev.package_name || "",
            version: ev.version || "",
            ts: timestampMillis(ev),
            ago: relativeTime(timestampMillis(ev), nowMillis),
            count: 1,
        });
    }
    rows.reverse();

    var collapsed = [];
    for (var j = 0; j < rows.length; j++) {
        var prev = collapsed.length ? collapsed[collapsed.length - 1] : null;
        if (prev && sameFeedRow(prev, rows[j])) {
            prev.count++;
        } else {
            collapsed.push(rows[j]);
        }
    }
    if (limit && collapsed.length > limit) collapsed = collapsed.slice(0, limit);
    return collapsed;
}

function sameFeedRow(a, b) {
    return a.pkg === b.pkg && a.version === b.version && a.ecosystem === b.ecosystem
        && a.severity === b.severity && a.verdict === b.verdict;
}

// Sum the per-package verdict events in one day's log. Do not count
// session_complete, because it repeats the totals and would double count.
function todayCounts(events) {
    var counts = { analyzed: 0, allowed: 0, blocked: 0, held: 0 };
    for (var i = 0; i < events.length; i++) {
        switch (severityOf(events[i])) {
        case "block":
            if (events[i].event_type === "malware_blocked") counts.blocked++;
            break;
        case "hold":
            counts.held++;
            break;
        case "allow":
            counts.allowed++;
            break;
        }
    }
    counts.analyzed = counts.allowed + counts.held + counts.blocked;
    return counts;
}

// Return block events newer than cutoffMillis, newest first. The Service uses
// this to alert only on new blocks and to skip history on start.
function newBlocksSince(events, cutoffMillis) {
    var out = [];
    for (var i = 0; i < events.length; i++) {
        if (isBlock(events[i]) && timestampMillis(events[i]) > cutoffMillis) {
            out.push(events[i]);
        }
    }
    out.sort(function (a, b) { return timestampMillis(b) - timestampMillis(a); });
    return out;
}

function relativeTime(tsMillis, nowMillis) {
    if (!tsMillis) return "";
    var delta = Math.max(0, (nowMillis || Date.now()) - tsMillis);
    var s = Math.floor(delta / 1000);
    if (s < 60) return "now";
    var m = Math.floor(s / 60);
    if (m < 60) return m + "m";
    var h = Math.floor(m / 60);
    if (h < 24) return h + "h";
    var d = Math.floor(h / 24);
    return d + "d";
}

// Return the date-stamped log file name PMG writes, like 20260815-pmg.log.
function dailyLogName(date) {
    var d = date || new Date();
    var y = d.getFullYear();
    var m = ("0" + (d.getMonth() + 1)).slice(-2);
    var day = ("0" + d.getDate()).slice(-2);
    return "" + y + m + day + "-pmg.log";
}

// Map the health field to a colour intent. Unknown reads as unprotected.
function healthSeverity(health) {
    switch (health) {
    case "protected":
        return "ok";
    case "degraded":
        return "warn";
    default:
        return "bad";
    }
}
