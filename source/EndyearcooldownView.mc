import Toybox.Application;
import Toybox.Application.Properties;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Math;
import Toybox.System;
import Toybox.Time;
import Toybox.Time.Gregorian;
import Toybox.Timer;
import Toybox.WatchUi;

// ---------------------------------------------------------------------------
// End year cooldown widget.
//
// Screen 0 (SCREEN_YEAR)  : countdown to the end of the school year, then the
//                           summer-break countdown to the next year. Fireworks
//                           when the year is over and a 10..1 second countdown
//                           in the last 10 seconds.
// Screen 1 (SCREEN_TODAY) : how much net school time is left *today*
//                           (08:00 -> that day's end time).
//
// Both screens draw a ring gauge showing how much of the school year has
// elapsed since September 1st.
//
// Switch screens with START / ENTER, NEXT / PREV, or a screen tap (handled by
// EndyearcooldownDelegate).
// ---------------------------------------------------------------------------

const SCREEN_YEAR = 0;
const SCREEN_TODAY = 1;
const SCREEN_COUNT = 2;

const SECONDS_PER_DAY = 86400;
const FIREWORKS_DURATION = 60; // seconds of fireworks after school ends
const SCHOOL_DAY_START_HOUR = 8;   // school day starts at 08:00
const SCHOOL_DAY_START_MIN = 0;

class EndyearcooldownView extends WatchUi.View {

    // Property keys (defined in resources/properties/properties.xml).
    const PROP_OFFICIAL_END_DATE = "officialEndDate";
    const PROP_ADJOINING_DAYS_OFF = "adjoiningDaysOff";
    const PROP_NEXT_YEAR_START_DATE = "nextYearStartDate";

    const PROP_DAY_END = [
        null,            // index 0 unused (Gregorian day_of_week is 1..7)
        "sundayEnd",
        "mondayEnd",
        "tuesdayEnd",
        "wednesdayEnd",
        "thursdayEnd",
        "fridayEnd",
        "saturdayEnd"
    ];

    const PROP_DAY_ENABLED = [
        null,
        "sundayEnabled",
        "mondayEnabled",
        "tuesdayEnabled",
        "wednesdayEnabled",
        "thursdayEnabled",
        "fridayEnabled",
        "saturdayEnabled"
    ];

    // Default end time per weekday (Sun..Sat), used when a setting is missing.
    const DEFAULT_END_HOUR = [ 0, 14, 14, 14, 14, 14, 12, 14 ];

    const TIMER_SLOW = 1000;  // normal refresh
    const TIMER_FAST = 100;   // fireworks / final countdown animation

    var _timer as Timer.Timer?;
    var _period as Number = TIMER_SLOW;
    var _wantFast as Boolean = false;
    var _frame as Number = 0;
    var _screen as Number = SCREEN_YEAR;

    // Cache for the net-school-time calculation: the summed school seconds of
    // all enabled days strictly *after* today only changes when the calendar
    // day rolls over, so we recompute it lazily instead of every second.
    var _netDayKey as Number = -1;
    var _netFutureFull as Number = 0;

    // ── DEBUG TIME OVERRIDE ──────────────────────────────────────────────────
    // Set DEBUG_ENABLED = true to shift the clock to June 30 13:59 (one
    // minute before the default 14:00 end time). The timer still ticks.
    // Set back to false before releasing.
    const DEBUG_ENABLED = false;
    var _debugOffset as Number = 0;
    // ─────────────────────────────────────────────────────────────────────────

    function initialize() {
        View.initialize();
        _timer = new Timer.Timer();
        if (DEBUG_ENABLED) {
            var target = Gregorian.moment({
                :year => 2026, :month => 6, :day => 30,
                :hour => 13, :minute => 59, :second => 0
            });
            _debugOffset = target.value() - Time.now().value();
        }
    }

    function onLayout(dc as Dc) as Void {
    }

    function onShow() as Void {
        startTimer(TIMER_SLOW);
    }

    function onHide() as Void {
        if (_timer != null) {
            (_timer as Timer.Timer).stop();
        }
    }

    function startTimer(period as Number) as Void {
        if (_timer != null) {
            (_timer as Timer.Timer).stop();
            (_timer as Timer.Timer).start(method(:onTick), period, true);
            _period = period;
        }
    }

    function onTick() as Void {
        _frame += 1;
        // Reconcile the timer period decided during the last draw.
        var desired = _wantFast ? TIMER_FAST : TIMER_SLOW;
        if (desired != _period) {
            startTimer(desired);
        }
        WatchUi.requestUpdate();
    }

    // Toggle handler called by the input delegate.
    // Blocked on the last school day and during summer break.
    function nextScreen() as Void {
        if (!isLockedToSingleScreen()) {
            _screen = (_screen + 1) % SCREEN_COUNT;
        }
        WatchUi.requestUpdate();
    }

    function previousScreen() as Void {
        if (!isLockedToSingleScreen()) {
            _screen = (_screen + SCREEN_COUNT - 1) % SCREEN_COUNT;
        }
        WatchUi.requestUpdate();
    }

    function isLockedToSingleScreen() as Boolean {
        var now = nowValue();
        var schoolEnd = schoolEndMoment().value();
        if (now >= schoolEnd) {
            return true;
        }
        // Lock on the last school day: midnight of that day until schoolEnd.
        var endInfo = Gregorian.info(schoolEndMoment(), Time.FORMAT_SHORT);
        var lastDayMidnight = momentAt(endInfo.year, endInfo.month, endInfo.day, 0, 0).value();
        return now >= lastDayMidnight;
    }

    // -----------------------------------------------------------------------
    // Drawing
    // -----------------------------------------------------------------------

    function onUpdate(dc as Dc) as Void {
        _wantFast = false;

        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();

        var width = dc.getWidth();
        var height = dc.getHeight();
        var now = nowValue();
        var schoolEnd = schoolEndMoment().value();
        var yearStart = schoolYearStartMoment().value();

        // Ring gauge: fraction of the school year that has elapsed.
        var yearPct = fraction(now - yearStart, schoolEnd - yearStart);
        drawProgressRing(dc, yearPct);

        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);

        // During summer: lock to single vacation screen, no switching.
        if (now >= schoolEnd) {
            var elapsed = now - schoolEnd;
            if (elapsed < FIREWORKS_DURATION) {
                _wantFast = true;
                drawFireworks(dc, width, height);
                drawFireworksOverlay(dc, width, height);
            } else {
                drawVacationCountdown(dc, now);
                drawScreenHint(dc, yearPct);
            }
            return;
        }

        if (_screen == SCREEN_TODAY) {
            drawNetSchoolScreen(dc, now, schoolEnd);
        } else {
            drawYearScreen(dc, now, schoolEnd);
        }

        drawScreenHint(dc, yearPct);
    }

    function drawYearScreen(dc as Dc, now as Number, schoolEnd as Number) as Void {
        var width = dc.getWidth();
        var height = dc.getHeight();
        var remaining = schoolEnd - now;

        if (remaining <= 10) {
            // Final 10 seconds: dramatic animated countdown.
            _wantFast = true;
            drawDramaticCountdown(dc, width, height, remaining);
            return;
        }

        var bodyFont = (width >= 240) ? Graphics.FONT_NUMBER_MEDIUM : Graphics.FONT_NUMBER_MILD;
        var days = remaining / SECONDS_PER_DAY;
        var rest = remaining % SECONDS_PER_DAY;
        var hours = rest / 3600;
        rest = rest % 3600;
        var minutes = rest / 60;
        var seconds = rest % 60;

        drawCentered(dc, "School ends in", width / 2, height * 16 / 100, Graphics.FONT_SMALL);

        if (days > 0) {
            drawCentered(dc, days.format("%d") + (days == 1 ? " day" : " days"), width / 2, height * 38 / 100, Graphics.FONT_LARGE);
            drawCentered(dc, twoDigits(hours) + ":" + twoDigits(minutes) + ":" + twoDigits(seconds), width / 2, height * 60 / 100, bodyFont);
            drawCentered(dc, "summer is close", width / 2, height * 80 / 100, Graphics.FONT_XTINY);
        } else if (hours > 0) {
            drawCentered(dc, hours.format("%d") + ":" + twoDigits(minutes) + ":" + twoDigits(seconds), width / 2, height * 48 / 100, bodyFont);
            drawCentered(dc, "hours left", width / 2, height * 70 / 100, Graphics.FONT_XTINY);
        } else if (minutes > 0) {
            drawCentered(dc, minutes.format("%d") + ":" + twoDigits(seconds), width / 2, height * 48 / 100, bodyFont);
            drawCentered(dc, "minutes left", width / 2, height * 70 / 100, Graphics.FONT_XTINY);
        } else {
            drawCentered(dc, seconds.format("%d"), width / 2, height * 48 / 100, bodyFont);
            drawCentered(dc, "seconds left", width / 2, height * 70 / 100, Graphics.FONT_XTINY);
        }
    }

    // Net learning time left from now until the end of the school year:
    // the sum of every remaining enabled school day's hours (08:00 -> that
    // day's end time). Ticks down second-by-second while school is in session.
    function drawNetSchoolScreen(dc as Dc, now as Number, schoolEnd as Number) as Void {
        var width = dc.getWidth();
        var height = dc.getHeight();
        var bodyFont = (width >= 240) ? Graphics.FONT_NUMBER_MEDIUM : Graphics.FONT_NUMBER_MILD;

        drawCentered(dc, "Net school time", width / 2, height * 16 / 100, Graphics.FONT_SMALL);

        if (now >= schoolEnd) {
            drawCentered(dc, "All done!", width / 2, height * 48 / 100, Graphics.FONT_MEDIUM);
            drawCentered(dc, "0 hours left", width / 2, height * 70 / 100, Graphics.FONT_XTINY);
            return;
        }

        var net = netSchoolSecondsRemaining(now, schoolEnd);
        var days = net / SECONDS_PER_DAY;
        var rest = net % SECONDS_PER_DAY;
        var hours = rest / 3600;
        rest = rest % 3600;
        var minutes = rest / 60;
        var seconds = rest % 60;

        if (days > 0) {
            drawCentered(dc, days.format("%d") + (days == 1 ? " day" : " days"), width / 2, height * 38 / 100, Graphics.FONT_LARGE);
            drawCentered(dc, twoDigits(hours) + ":" + twoDigits(minutes) + ":" + twoDigits(seconds), width / 2, height * 60 / 100, bodyFont);
            drawCentered(dc, "of learning left", width / 2, height * 80 / 100, Graphics.FONT_XTINY);
        } else {
            drawCentered(dc, hms(net), width / 2, height * 50 / 100, bodyFont);
            drawCentered(dc, "of learning left", width / 2, height * 72 / 100, Graphics.FONT_XTINY);
        }
    }

    // Sum of remaining school seconds from `now` until the end of the year.
    // The future-days portion only changes at midnight, so it is cached.
    function netSchoolSecondsRemaining(now as Number, schoolEnd as Number) as Number {
        if (now >= schoolEnd) {
            return 0;
        }

        var todayInfo = Gregorian.info(new Time.Moment(nowValue()), Time.FORMAT_SHORT);
        var todayKey = todayInfo.year * 10000 + todayInfo.month * 100 + todayInfo.day;
        if (todayKey != _netDayKey) {
            _netDayKey = todayKey;
            _netFutureFull = sumFutureSchoolSeconds(todayInfo, schoolEnd);
        }

        return netTodaySeconds(now, todayInfo, schoolEnd) + _netFutureFull;
    }

    // School seconds still available *today* from `now` onward.
    function netTodaySeconds(now as Number, todayInfo as Gregorian.Info, schoolEnd as Number) as Number {
        if (!isDayEnabled(todayInfo.day_of_week)) {
            return 0;
        }
        var startVal = momentAt(todayInfo.year, todayInfo.month, todayInfo.day, SCHOOL_DAY_START_HOUR, SCHOOL_DAY_START_MIN).value();
        var endParts = endTimeForDow(todayInfo.day_of_week);
        var endVal = momentAt(todayInfo.year, todayInfo.month, todayInfo.day, endParts[0], endParts[1]).value();
        if (endVal > schoolEnd) {
            endVal = schoolEnd;
        }
        var segStart = (now > startVal) ? now : startVal;
        return (endVal > segStart) ? endVal - segStart : 0;
    }

    // Full school seconds (08:00 -> end time) for every enabled day strictly
    // after today, up to and including the last school day.
    function sumFutureSchoolSeconds(todayInfo as Gregorian.Info, schoolEnd as Number) as Number {
        var day = momentAt(todayInfo.year, todayInfo.month, todayInfo.day, 0, 0)
            .add(new Time.Duration(SECONDS_PER_DAY));
        var total = 0;
        var guard = 0;
        while (day.value() < schoolEnd and guard < 400) {
            var di = Gregorian.info(day, Time.FORMAT_SHORT);
            if (isDayEnabled(di.day_of_week)) {
                var startVal = momentAt(di.year, di.month, di.day, SCHOOL_DAY_START_HOUR, SCHOOL_DAY_START_MIN).value();
                var endParts = endTimeForDow(di.day_of_week);
                var endVal = momentAt(di.year, di.month, di.day, endParts[0], endParts[1]).value();
                if (endVal > schoolEnd) {
                    endVal = schoolEnd;
                }
                if (endVal > startVal) {
                    total += endVal - startVal;
                }
            }
            day = day.add(new Time.Duration(SECONDS_PER_DAY));
            guard += 1;
        }
        return total;
    }

    function drawVacationCountdown(dc as Dc, now as Number) as Void {
        var width = dc.getWidth();
        var height = dc.getHeight();
        var nextStart = nextYearStartMoment();
        var remaining = nextStart.value() - now;
        var info = Gregorian.info(nextStart, Time.FORMAT_SHORT);

        var daysLeft = 0;
        if (remaining > 0) {
            daysLeft = (remaining + SECONDS_PER_DAY - 1) / SECONDS_PER_DAY;
        }

        dc.setColor(Graphics.COLOR_YELLOW, Graphics.COLOR_TRANSPARENT);
        drawCentered(dc, "School is over!", width / 2, height * 16 / 100, Graphics.FONT_SMALL);
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);

        if (remaining > 0) {
            drawCentered(dc, daysLeft.format("%d"), width / 2, height * 46 / 100, Graphics.FONT_NUMBER_MEDIUM);
            drawCentered(dc, (daysLeft == 1 ? "day until" : "days until"), width / 2, height * 68 / 100, Graphics.FONT_XTINY);
            drawCentered(dc, dateLabel(info), width / 2, height * 80 / 100, Graphics.FONT_XTINY);
        } else {
            drawCentered(dc, "Welcome back!", width / 2, height * 50 / 100, Graphics.FONT_MEDIUM);
        }
    }

    // Small label at the bottom telling the user how to switch screens and the
    // overall year progress percentage.
    function drawScreenHint(dc as Dc, yearPct as Float) as Void {
        var width = dc.getWidth();
        var height = dc.getHeight();
        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
        drawCentered(dc, (yearPct * 100).format("%d") + "% of year", width / 2, height * 92 / 100, Graphics.FONT_XTINY);
    }

    function nowValue() as Number {
        return Time.now().value() + _debugOffset;
    }

    function drawCentered(dc as Dc, text as String, x as Number, y as Number, font as Graphics.FontType) as Void {
        dc.drawText(x, y, font, text, Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    // Ring gauge around the edge showing the elapsed fraction of the year.
    function drawProgressRing(dc as Dc, pct as Float) as Void {
        var width = dc.getWidth();
        var height = dc.getHeight();
        var cx = width / 2;
        var cy = height / 2;
        var radius = ((width < height ? width : height) / 2) - 5;
        if (radius < 4) {
            return;
        }

        dc.setPenWidth(6);
        dc.setColor(Graphics.COLOR_DK_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawCircle(cx, cy, radius);

        if (pct <= 0.0) {
            dc.setPenWidth(1);
            return;
        }

        dc.setColor(Graphics.COLOR_BLUE, Graphics.COLOR_TRANSPARENT);
        if (pct >= 0.999) {
            dc.drawCircle(cx, cy, radius);
        } else {
            // Start at the top (90 deg) and sweep clockwise.
            var endDeg = 90.0 - 360.0 * pct;
            while (endDeg < 0.0) {
                endDeg += 360.0;
            }
            dc.drawArc(cx, cy, radius, Graphics.ARC_CLOCKWISE, 90, endDeg.toNumber());
        }
        dc.setPenWidth(1);
    }

    // Deterministic-per-frame fireworks so the picture is stable within a frame
    // but animates across frames.
    function drawFireworks(dc as Dc, width as Number, height as Number) as Void {
        var bursts = 3;
        var cycle = 18; // frames per burst lifetime
        var palette = [
            Graphics.COLOR_YELLOW,
            Graphics.COLOR_RED,
            Graphics.COLOR_GREEN,
            Graphics.COLOR_BLUE,
            Graphics.COLOR_PINK,
            Graphics.COLOR_ORANGE
        ];

        for (var i = 0; i < bursts; i += 1) {
            var f = (_frame + i * 6) % cycle;
            if (f >= 13) {
                continue; // gap between bursts
            }
            var era = (_frame + i * 6) / cycle; // which burst we are showing
            var seed = era * 31 + i * 7 + 1;

            var cx = 20 + rnd(seed) % (width > 40 ? width - 40 : 1);
            var cy = 25 + rnd(seed + 1) % (height > 70 ? height - 70 : 1);
            var color = palette[rnd(seed + 2) % palette.size()];
            var radius = 6 + f * 5;

            dc.setColor(color, Graphics.COLOR_TRANSPARENT);
            dc.setPenWidth(2);
            var rays = 10;
            for (var r = 0; r < rays; r += 1) {
                var ang = (Math.PI * 2.0 * r) / rays;
                var ex = cx + (radius * Math.cos(ang)).toNumber();
                var ey = cy + (radius * Math.sin(ang)).toNumber();
                dc.drawLine(cx, cy, ex, ey);
                dc.fillCircle(ex, ey, 2);
            }
        }
        dc.setPenWidth(1);
    }

    // Dramatic 10..1 animated countdown: pulsing color + radiating spikes.
    function drawDramaticCountdown(dc as Dc, width as Number, height as Number, remaining as Number) as Void {
        var cx = width / 2;
        var cy = height / 2;

        // Cycle colors quickly: yellow → orange → red → pink → repeat.
        var palette = [
            Graphics.COLOR_YELLOW,
            Graphics.COLOR_ORANGE,
            Graphics.COLOR_RED,
            Graphics.COLOR_PINK,
            Graphics.COLOR_RED,
            Graphics.COLOR_ORANGE
        ];
        var color = palette[_frame % palette.size()];

        // Radiating spikes that grow outward each sub-frame.
        var spikes = 12;
        var inner = 18;
        var outer = inner + (_frame % 10) * 4;
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(2);
        for (var s = 0; s < spikes; s += 1) {
            var ang = (Math.PI * 2.0 * s) / spikes;
            dc.drawLine(
                cx + (inner * Math.cos(ang)).toNumber(),
                cy + (inner * Math.sin(ang)).toNumber(),
                cx + (outer * Math.cos(ang)).toNumber(),
                cy + (outer * Math.sin(ang)).toNumber()
            );
        }
        dc.setPenWidth(1);

        // Big flashing number.
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        var bigFont = Graphics.FONT_NUMBER_HOT;
        drawCentered(dc, remaining.format("%d"), cx, cy, bigFont);

        // Label above and below.
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        drawCentered(dc, "SUMMER IN", cx, height * 18 / 100, Graphics.FONT_SMALL);
        drawCentered(dc, "SECONDS!", cx, height * 84 / 100, Graphics.FONT_SMALL);
    }

    // Text overlay shown on top of fireworks for the 60-second celebration.
    function drawFireworksOverlay(dc as Dc, width as Number, height as Number) as Void {
        var cx = width / 2;
        // Alternate between two celebration lines every ~10 frames.
        var lines = ["SCHOOL IS", "OVER! :D"];
        var palette = [
            Graphics.COLOR_YELLOW,
            Graphics.COLOR_GREEN,
            Graphics.COLOR_PINK,
            Graphics.COLOR_ORANGE
        ];
        dc.setColor(palette[(_frame / 5) % palette.size()], Graphics.COLOR_TRANSPARENT);
        drawCentered(dc, lines[(_frame / 10) % 2], cx, height * 50 / 100, Graphics.FONT_LARGE);
    }

    // -----------------------------------------------------------------------
    // School schedule calculation
    // -----------------------------------------------------------------------

    // Absolute moment when the school year ends, accounting for adjoining days
    // off and disabled weekdays, evaluated at that day's configured end time.
    function schoolEndMoment() as Time.Moment {
        var parts = parseDateSetting(PROP_OFFICIAL_END_DATE, 2026, 6, 30);
        var adjoining = numberSetting(PROP_ADJOINING_DAYS_OFF, 0);
        if (adjoining < 0) {
            adjoining = 0;
        }

        var day = momentAt(parts[0], parts[1], parts[2], 0, 0)
            .subtract(new Time.Duration(adjoining * SECONDS_PER_DAY));

        // Walk back to the last enabled school day (guarded against no days on).
        var guard = 0;
        while (guard < 14 and !isDayEnabled(Gregorian.info(day, Time.FORMAT_SHORT).day_of_week)) {
            day = day.subtract(new Time.Duration(SECONDS_PER_DAY));
            guard += 1;
        }

        var info = Gregorian.info(day, Time.FORMAT_SHORT);
        var endParts = endTimeForDow(info.day_of_week);
        return momentAt(info.year, info.month, info.day, endParts[0], endParts[1]);
    }

    // September 1st of the current school year (08:00), used for the gauge.
    function schoolYearStartMoment() as Time.Moment {
        var parts = parseDateSetting(PROP_OFFICIAL_END_DATE, 2026, 6, 30);
        var endYear = parts[0];
        var endMonth = parts[1];
        var startYear = (endMonth >= 9) ? endYear : endYear - 1;
        return momentAt(startYear, 9, 1, SCHOOL_DAY_START_HOUR, SCHOOL_DAY_START_MIN);
    }

    function nextYearStartMoment() as Time.Moment {
        var parts = parseDateSetting(PROP_NEXT_YEAR_START_DATE, 2026, 9, 1);
        return momentAt(parts[0], parts[1], parts[2], SCHOOL_DAY_START_HOUR, SCHOOL_DAY_START_MIN);
    }

    function momentAt(year as Number, month as Number, day as Number, hour as Number, minute as Number) as Time.Moment {
        return Gregorian.moment({
            :year => year,
            :month => month,
            :day => day,
            :hour => hour,
            :minute => minute,
            :second => 0
        });
    }

    function endTimeForDow(dow as Number) as Array<Number> {
        if (dow < 1 or dow > 7) {
            dow = 1;
        }
        return parseTimeSetting(PROP_DAY_END[dow], DEFAULT_END_HOUR[dow], 0);
    }

    function isDayEnabled(dow as Number) as Boolean {
        if (dow < 1 or dow > 7) {
            return false;
        }
        // Saturday defaults to off, every other day defaults to on.
        var def = (dow != 7);
        return booleanSetting(PROP_DAY_ENABLED[dow], def);
    }

    // -----------------------------------------------------------------------
    // Settings access (uses Application.Properties so live setting changes from
    // Garmin Connect are picked up - the old AppBase.getProperty read a
    // different store and ignored them).
    // -----------------------------------------------------------------------

    function readProperty(key as String) as Application.PropertyValueType {
        return Properties.getValue(key);
    }

    function numberSetting(key as String, defaultValue as Number) as Number {
        var value = readProperty(key);
        if (value instanceof Number) {
            return value;
        }
        if (value instanceof Float or value instanceof Double) {
            return value.toNumber();
        }
        if (value instanceof String) {
            var n = (value as String).toNumber();
            return (n == null) ? defaultValue : n;
        }
        return defaultValue;
    }

    function booleanSetting(key as String, defaultValue as Boolean) as Boolean {
        var value = readProperty(key);
        if (value instanceof Boolean) {
            return value;
        }
        if (value instanceof Number) {
            return value != 0;
        }
        if (value instanceof String) {
            var t = value as String;
            return t.equals("true") or t.equals("True") or t.equals("1");
        }
        return defaultValue;
    }

    // Returns [year, month, day]. Date settings are stored as UTC-midnight epoch
    // seconds; we also accept "YYYY-MM-DD" strings.
    function parseDateSetting(key as String, defY as Number, defM as Number, defD as Number) as Array<Number> {
        var value = readProperty(key);
        if (value instanceof Number or value instanceof Float or value instanceof Double) {
            var secs = value.toNumber();
            var utc = Gregorian.utcInfo(new Time.Moment(secs), Time.FORMAT_SHORT);
            return [ utc.year, utc.month, utc.day ];
        }
        if (value instanceof String) {
            var text = value as String;
            if (text.length() >= 10) {
                var y = text.substring(0, 4).toNumber();
                var m = text.substring(5, 7).toNumber();
                var d = text.substring(8, 10).toNumber();
                if (y != null and m != null and d != null) {
                    return [ y, m, d ];
                }
            }
        }
        return [ defY, defM, defD ];
    }

    // Returns [hour, minute] parsed from a "HH:MM" string.
    function parseTimeSetting(key as String, defH as Number, defM as Number) as Array<Number> {
        var value = readProperty(key);
        if (value instanceof String) {
            var text = value as String;
            if (text.length() >= 4) {
                var sep = text.find(":");
                if (sep != null and sep >= 1) {
                    var h = text.substring(0, sep).toNumber();
                    var m = text.substring(sep + 1, text.length()).toNumber();
                    if (h != null and m != null and h >= 0 and h <= 23 and m >= 0 and m <= 59) {
                        return [ h, m ];
                    }
                }
            }
        }
        return [ defH, defM ];
    }

    // -----------------------------------------------------------------------
    // Small helpers
    // -----------------------------------------------------------------------

    // Clamped fraction num/den in [0.0, 1.0].
    function fraction(num as Number, den as Number) as Float {
        if (den <= 0) {
            return (num <= 0) ? 0.0 : 1.0;
        }
        var f = num.toFloat() / den.toFloat();
        if (f < 0.0) {
            return 0.0;
        }
        if (f > 1.0) {
            return 1.0;
        }
        return f;
    }

    // Seconds -> "H:MM:SS".
    function hms(totalSeconds as Number) as String {
        if (totalSeconds < 0) {
            totalSeconds = 0;
        }
        var hours = totalSeconds / 3600;
        var rest = totalSeconds % 3600;
        var minutes = rest / 60;
        var seconds = rest % 60;
        return hours.format("%d") + ":" + twoDigits(minutes) + ":" + twoDigits(seconds);
    }

    function twoDigits(value as Number) as String {
        if (value < 10) {
            return "0" + value.format("%d");
        }
        return value.format("%d");
    }

    function dateLabel(info as Gregorian.Info) as String {
        return twoDigits(info.day) + "/" + twoDigits(info.month) + "/" + info.year.format("%d");
    }

    // Tiny deterministic pseudo-random generator for the fireworks.
    function rnd(seed as Number) as Number {
        var x = (seed * 1103515245 + 12345) & 0x7fffffff;
        return x;
    }
}
