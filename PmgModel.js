.pragma library

// PmgModel is the pure, UI-free core of the plugin: it turns PMG's JSONL event
// log lines and `pmg setup info --json` output into the small shapes the QML
// binds to. Keeping it framework-free makes the logic testable with plain JS
// (see test/model.test.mjs) and keeps the QML declarative.

// Verdict vocabulary from internal/audit/event.go, mapped to a display severity.
// "block" is the security win (red), "hold" is a cooldown deferral (amber),
// "allow" is a clean install (green), "info" is context we show muted.
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
    malware_blocked: "malware blocked",
    malware_confirmed: "malware allowed by user",
    install_insecure_bypass: "insecure bypass",
    dependency_cooldown: "cooldown hold",
    install_allowed: "allowed",
    install_trusted_allowed: "trusted",
    sandbox_override: "sandbox override",
};

// Events worth showing in the activity feed. Lifecycle/bookkeeping events
// (install_started, dependency_resolved, proxy_host_observed, session_complete,
// dependency_cooldown_skipped) are intentionally excluded.
function isDisplayable(ev) {
    return !!ev && SEVERITY.hasOwnProperty(ev.event_type);
}

// A malware_blocked event is the moment the overlay fires. malware_confirmed is
// a user override (they proceeded), so it is not a "we blocked it" moment.
function isBlock(ev) {
    return !!ev && ev.event_type === "malware_blocked";
}

function severityOf(ev) {
    return (ev && SEVERITY[ev.event_type]) || "info";
}

function labelOf(ev) {
    return (ev && LABEL[ev.event_type]) || (ev ? ev.event_type : "");
}

// parseLine turns one JSONL line into an event object, or null for blanks and
// malformed lines (a corrupt line must never break the feed).
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

// humanizeEcosystem turns PMG's proto-enum ecosystem string into a friendly
// label: "ECOSYSTEM_PYPI" -> "pypi", "npm" -> "npm". Unspecified/unknown enum
// values become "" so the UI shows nothing rather than noise.
function humanizeEcosystem(eco) {
    var s = String(eco || "").replace(/^ECOSYSTEM_/i, "").toLowerCase();
    if (s === "unspecified" || s === "unknown") return "";
    return s;
}

// feedRows projects displayable events into newest-first view rows, capped.
function feedRows(events, limit, nowMillis) {
    var rows = [];
    for (var i = 0; i < events.length; i++) {
        var ev = events[i];
        if (!isDisplayable(ev)) continue;
        var pkg = ev.package_name || "";
        rows.push({
            severity: severityOf(ev),
            verdict: labelOf(ev),
            ecosystem: humanizeEcosystem(ev.ecosystem),
            pkg: pkg,
            version: ev.version || "",
            ts: timestampMillis(ev),
            ago: relativeTime(timestampMillis(ev), nowMillis),
        });
    }
    rows.reverse();
    if (limit && rows.length > limit) rows = rows.slice(0, limit);
    return rows;
}

// todayCounts sums the per-package verdict events in one day's log. session_complete
// carries the same totals as a per-run rollup, so it is deliberately not counted
// here (that would double count the individual events).
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

// newBlocksSince returns malware_blocked events strictly newer than cutoffMillis,
// newest first. The Service uses this to fire the overlay only for genuinely new
// blocks, never replaying history on shell restart / first load.
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

// dailyLogName returns the date-stamped log file name PMG writes for a given
// date (see internal/eventlog: "20060102-pmg.log"). The Service recomputes this
// so the feed follows the file across midnight rotation.
function dailyLogName(date) {
    var d = date || new Date();
    var y = d.getFullYear();
    var m = ("0" + (d.getMonth() + 1)).slice(-2);
    var day = ("0" + d.getDate()).slice(-2);
    return "" + y + m + day + "-pmg.log";
}

// healthSeverity maps the `health` field from `pmg setup info --json` to the
// widget's colour intent. Unknown/missing reads as unprotected.
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
