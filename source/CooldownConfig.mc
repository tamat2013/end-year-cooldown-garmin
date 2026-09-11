import Toybox.Lang;
import Toybox.System;
import Toybox.Time;
import Toybox.Time.Gregorian;

// Parsed configuration decoded from the "cooldownSeed" web-UI seed string.
// All widget behavior comes from this object - there are no other settings.
//
// The school-end and next-year-start dates are stored as month/day only (no
// year), so the same seed works forever: schoolEndMoment()/nextYearStartMoment()
// pick whichever calendar year is currently relevant.
class CooldownConfig {
    var endMonth as Number;
    var endDay as Number;
    var nextStartMonth as Number;
    var nextStartDay as Number;
    var accentColor as Number;
    var schoolStartHour as Number;
    var schoolStartMinute as Number;

    // Index 0=Sun..6=Sat.
    var dayEnabled as Array<Boolean>;
    var dayEndHour as Array<Number>;
    var dayEndMinute as Array<Number>;

    function initialize(
        dateParts as Array<Number>,
        accent as Number,
        startHour as Number,
        startMinute as Number,
        enabled as Array<Boolean>,
        endHour as Array<Number>,
        endMinute as Array<Number>
    ) {
        endMonth = dateParts[0];
        endDay = dateParts[1];
        nextStartMonth = dateParts[2];
        nextStartDay = dateParts[3];
        accentColor = accent;
        schoolStartHour = startHour;
        schoolStartMinute = startMinute;
        dayEnabled = enabled;
        dayEndHour = endHour;
        dayEndMinute = endMinute;
    }

    // Splits `s` on single-character delimiter `delim` (Monkey C's String has no split()).
    static function splitStr(s as String, delim as String) as Array<String> {
        var result = [] as Array<String>;
        var start = 0;
        var idx = s.find(delim);
        while (idx != null) {
            result.add(s.substring(start, idx) as String);
            start = idx + delim.length();
            idx = s.substring(start, s.length()).find(delim);
            if (idx != null) { idx += start; }
        }
        result.add(s.substring(start, s.length()) as String);
        return result;
    }

    // Decodes a base36 string (0-9, a-z) into a Number.
    static function fromBase36(s as String) as Number {
        var digits = "0123456789abcdefghijklmnopqrstuvwxyz";
        var value = 0;
        for (var i = 0; i < s.length(); i++) {
            var c = s.substring(i, i + 1);
            var d = digits.find(c);
            if (d == null) { return 0; }
            value = value * 36 + d;
        }
        return value;
    }

    // Seed format (produced by web/index.html):
    // 2|E=<b36 month*100+day>|N=<b36 month*100+day>|W=<decimal bitmask, bit0=Sun..bit6=Sat>|T=<b36 endMinutes Sun,Mon,...,Sat>|C=<decimal 0-7>|S=<b36 startMinutes>
    static function parse(seed as String) as CooldownConfig? {
        if (seed.length() < 2 or !seed.substring(0, 2).equals("2|")) {
            return null;
        }
        var sections = CooldownConfig.splitStr(seed.substring(2, seed.length()), "|");
        var eStr = null;
        var nStr = null;
        var wStr = null;
        var tStr = null;
        var cStr = null;
        var sStr = null;
        for (var i = 0; i < sections.size(); i++) {
            var s = sections[i] as String;
            if (s.find("E=") == 0) { eStr = s.substring(2, s.length()); }
            else if (s.find("N=") == 0) { nStr = s.substring(2, s.length()); }
            else if (s.find("W=") == 0) { wStr = s.substring(2, s.length()); }
            else if (s.find("T=") == 0) { tStr = s.substring(2, s.length()); }
            else if (s.find("C=") == 0) { cStr = s.substring(2, s.length()); }
            else if (s.find("S=") == 0) { sStr = s.substring(2, s.length()); }
        }
        if (eStr == null or nStr == null or wStr == null or tStr == null or cStr == null or sStr == null) {
            return null;
        }

        var tParts = CooldownConfig.splitStr(tStr as String, ",");
        if (tParts.size() != 7) {
            return null;
        }

        var days = (wStr as String).toNumber();
        var accent = (cStr as String).toNumber();
        if (days == null or accent == null) {
            return null;
        }

        var enabled = [] as Array<Boolean>;
        var endHour = [] as Array<Number>;
        var endMinute = [] as Array<Number>;
        for (var i = 0; i < 7; i++) {
            enabled.add(((days >> i) & 1) == 1);
            var minutes = CooldownConfig.fromBase36(tParts[i] as String);
            endHour.add(minutes / 60);
            endMinute.add(minutes % 60);
        }

        var startMinutes = CooldownConfig.fromBase36(sStr as String);
        var eVal = CooldownConfig.fromBase36(eStr as String);
        var nVal = CooldownConfig.fromBase36(nStr as String);

        return new CooldownConfig(
            [ eVal / 100, eVal % 100, nVal / 100, nVal % 100 ] as Array<Number>,
            accent,
            startMinutes / 60,
            startMinutes % 60,
            enabled,
            endHour,
            endMinute
        );
    }

    // Corrects for the Garmin SDK quirk where Gregorian.moment() interprets
    // its fields as UTC rather than local time.
    function momentAt(year as Number, month as Number, day as Number, hour as Number, minute as Number) as Time.Moment {
        var offset = System.getClockTime().timeZoneOffset;
        return Gregorian.moment({
            :year => year,
            :month => month,
            :day => day,
            :hour => hour,
            :minute => minute,
            :second => 0
        }).subtract(new Time.Duration(offset));
    }

    // The calendar year whose E/N dates apply to `now`. E and N always fall
    // in the same calendar year (e.g. school ends June 2026, next year starts
    // September 2026); once this year's N has passed, the next cycle's E and
    // N are both in the following calendar year.
    function cycleYear(now as Number) as Number {
        var thisYear = Gregorian.info(new Time.Moment(now), Time.FORMAT_SHORT).year;
        var nMoment = momentAt(thisYear, nextStartMonth, nextStartDay, schoolStartHour, schoolStartMinute).value();
        return (now > nMoment) ? thisYear + 1 : thisYear;
    }

    // Absolute moment when the school year ends, accounting for disabled
    // weekdays, evaluated at that day's configured end time.
    function schoolEndMoment(now as Number) as Time.Moment {
        var year = cycleYear(now);
        var day = momentAt(year, endMonth, endDay, 0, 0);

        // Walk back to the last enabled school day (guarded against no days on).
        var guard = 0;
        while (guard < 14 and !dayEnabled[Gregorian.info(day, Time.FORMAT_SHORT).day_of_week - 1]) {
            day = day.subtract(new Time.Duration(86400));
            guard += 1;
        }

        var info = Gregorian.info(day, Time.FORMAT_SHORT);
        var idx = info.day_of_week - 1;
        return momentAt(info.year, info.month, info.day, dayEndHour[idx], dayEndMinute[idx]);
    }

    function nextYearStartMoment(now as Number) as Time.Moment {
        var year = cycleYear(now);
        return momentAt(year, nextStartMonth, nextStartDay, schoolStartHour, schoolStartMinute);
    }

    // September 1st of the current school year (08:00), used for the gauge.
    function schoolYearStartMoment(now as Number) as Time.Moment {
        var year = cycleYear(now);
        var startYear = (endMonth >= 9) ? year : year - 1;
        return momentAt(startYear, 9, 1, schoolStartHour, schoolStartMinute);
    }
}
