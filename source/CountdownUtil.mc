import Toybox.Lang;
import Toybox.Time;
import Toybox.Time.Gregorian;
import Toybox.Application;

// All countdown / calendar maths live here. The class is annotated (:glance)
// so the very same symbol is available both to the lightweight glance build
// and to the full application build.
(:glance)
class CountdownUtil {

    // The "net school hours" window needs a daily start time. The settings only
    // expose the final bell, so we assume a fixed opening hour for the building.
    public static const SCHOOL_START_HOUR = 8;
    public static const SCHOOL_START_MIN = 0;

    // How long the fireworks celebration lasts after the zero hour (seconds).
    public static const CELEBRATION_SECONDS = 12;

    public static const SECONDS_PER_DAY = 86400;

    // ---- Simple day-keyed cache for the (expensive) net-hours computation ----
    static var sCacheDay = -1;
    static var sCacheFutureFull = 0;

    static function invalidateCache() as Void {
        sCacheDay = -1;
        sCacheFutureFull = 0;
    }

    // ------------------------------------------------------------------ //
    //  Property helpers                                                   //
    // ------------------------------------------------------------------ //

    static function numProp(key as String) as Number {
        var v = Application.Properties.getValue(key);
        if (v instanceof Lang.Number) {
            return v as Number;
        }
        if (v instanceof Lang.Float) {
            return (v as Float).toNumber();
        }
        if (v instanceof Lang.Long) {
            return (v as Long).toNumber();
        }
        return 0;
    }

    static function boolProp(key as String) as Boolean {
        var v = Application.Properties.getValue(key);
        if (v instanceof Lang.Boolean) {
            return v as Boolean;
        }
        return false;
    }

    static function strProp(key as String) as String {
        var v = Application.Properties.getValue(key);
        if (v instanceof Lang.String) {
            return v as String;
        }
        return "10:00";
    }

    // Index 0 = Sunday ... 6 = Saturday (matches Gregorian day_of_week - 1).
    static function isSchoolDay(dowIndex as Number) as Boolean {
        var keys = ["SchoolDaySun", "SchoolDayMon", "SchoolDayTue", "SchoolDayWed",
                    "SchoolDayThu", "SchoolDayFri", "SchoolDaySat"];
        return boolProp(keys[dowIndex]);
    }

    // Returns [hour, minute] parsed from the "HH:MM" daily-end property.
    static function parseEndHour(dowIndex as Number) as Array<Number> {
        var keys = ["EndHourSun", "EndHourMon", "EndHourTue", "EndHourWed",
                    "EndHourThu", "EndHourFri", "EndHourSat"];
        var s = strProp(keys[dowIndex]);
        var sep = s.find(":");
        if (sep == null) {
            return [16, 0];
        }
        var hh = s.substring(0, sep).toNumber();
        var mm = s.substring(sep + 1, s.length()).toNumber();
        if (hh == null) { hh = 16; }
        if (mm == null) { mm = 0; }
        return [hh, mm];
    }

    // ------------------------------------------------------------------ //
    //  Date primitives                                                    //
    // ------------------------------------------------------------------ //

    static function makeMoment(year as Number, month as Number, day as Number,
                               hour as Number, minute as Number) as Time.Moment {
        return Gregorian.moment({
            :year => year,
            :month => month,
            :day => day,
            :hour => hour,
            :minute => minute,
            :second => 0
        });
    }

    static function midnightOf(m as Time.Moment) as Time.Moment {
        var info = Gregorian.info(m, Time.FORMAT_SHORT);
        return makeMoment(info.year as Number, info.month as Number, info.day as Number, 0, 0);
    }

    // Robust +/- one calendar day that survives daylight-saving transitions:
    // step a partial day then re-snap to local midnight.
    static function nextMidnight(m as Time.Moment) as Time.Moment {
        return midnightOf(m.add(new Time.Duration(129600))); // +36h, then snap
    }

    static function prevMidnight(m as Time.Moment) as Time.Moment {
        return midnightOf(m.subtract(new Time.Duration(43200))); // -12h, then snap
    }

    // Converts a YYYYMMDD integer (e.g. 20260630) to local-midnight Moment.
    // Using date integers instead of Unix timestamps avoids UTC/local ambiguity.
    static function yyyymmddToMidnight(yyyymmdd as Number) as Time.Moment {
        var y = yyyymmdd / 10000;
        var m = (yyyymmdd % 10000) / 100;
        var d = yyyymmdd % 100;
        return makeMoment(y, m, d, 0, 0);
    }

    // ------------------------------------------------------------------ //
    //  Calibrated zero hour                                               //
    // ------------------------------------------------------------------ //

    // The continuous countdown target. Snaps backward from the official end
    // (or the day before connected holidays) to the closing bell of the last
    // *active* school day.
    static function getCalibratedEndMoment() as Time.Moment {
        var officialDate = numProp("OfficialEndDate");
        var holidayDate = numProp("ConnectedHolidaysStart");

        var boundary;
        if (holidayDate > 0 && holidayDate <= officialDate) {
            // The last school day is the one right before the holidays begin.
            boundary = prevMidnight(yyyymmddToMidnight(holidayDate));
        } else {
            boundary = yyyymmddToMidnight(officialDate);
        }

        for (var i = 0; i < 14; i++) {
            var info = Gregorian.info(boundary, Time.FORMAT_SHORT);
            var dowIndex = (info.day_of_week as Number) - 1;
            if (isSchoolDay(dowIndex)) {
                var bell = parseEndHour(dowIndex);
                return makeMoment(info.year as Number, info.month as Number,
                                  info.day as Number, bell[0], bell[1]);
            }
            boundary = prevMidnight(boundary);
        }

        // Fallback: treat the official date as the literal zero hour.
        return yyyymmddToMidnight(officialDate);
    }

    // ------------------------------------------------------------------ //
    //  Net school-hours remaining                                         //
    // ------------------------------------------------------------------ //

    // Full in-building window length for a given school day, clamped so it
    // never extends past the overall calibrated end.
    static function windowSeconds(info as Gregorian.Info, dowIndex as Number,
                                  endValue as Number) as Number {
        var bell = parseEndHour(dowIndex);
        var ws = makeMoment(info.year as Number, info.month as Number, info.day as Number,
                            SCHOOL_START_HOUR, SCHOOL_START_MIN).value();
        var we = makeMoment(info.year as Number, info.month as Number, info.day as Number,
                            bell[0], bell[1]).value();
        if (we > endValue) { we = endValue; }
        if (we <= ws) { return 0; }
        return we - ws;
    }

    static function getNetSecondsRemaining(now as Time.Moment) as Number {
        var endMoment = getCalibratedEndMoment();
        var endValue = endMoment.value();
        var nowValue = now.value();
        if (nowValue >= endValue) {
            return 0;
        }

        var todayMidnight = midnightOf(now);
        var todayKey = todayMidnight.value();

        // Days strictly after today are stable until the date rolls over, so
        // cache their summed full windows and only recompute once per day.
        if (sCacheDay != todayKey) {
            var total = 0;
            var cursor = nextMidnight(todayMidnight);
            for (var i = 0; i < 400; i++) {
                if (cursor.value() > endValue) {
                    break;
                }
                var info = Gregorian.info(cursor, Time.FORMAT_SHORT);
                var dowIndex = (info.day_of_week as Number) - 1;
                if (isSchoolDay(dowIndex)) {
                    total += windowSeconds(info, dowIndex, endValue);
                }
                cursor = nextMidnight(cursor);
            }
            sCacheFutureFull = total;
            sCacheDay = todayKey;
        }

        // Today's live remaining contribution.
        var todayContribution = 0;
        var tinfo = Gregorian.info(todayMidnight, Time.FORMAT_SHORT);
        var tdow = (tinfo.day_of_week as Number) - 1;
        if (isSchoolDay(tdow)) {
            var bell = parseEndHour(tdow);
            var ws = makeMoment(tinfo.year as Number, tinfo.month as Number, tinfo.day as Number,
                                SCHOOL_START_HOUR, SCHOOL_START_MIN).value();
            var we = makeMoment(tinfo.year as Number, tinfo.month as Number, tinfo.day as Number,
                                bell[0], bell[1]).value();
            if (we > endValue) { we = endValue; }
            var effStart = ws;
            if (nowValue > effStart) { effStart = nowValue; }
            if (we > effStart) {
                todayContribution = we - effStart;
            }
        }

        return sCacheFutureFull + todayContribution;
    }

    // ------------------------------------------------------------------ //
    //  Progress + summer break                                            //
    // ------------------------------------------------------------------ //

    // Derived school-year start: the 1st of September on or before the end.
    static function getYearStartMoment(endMoment as Time.Moment) as Time.Moment {
        var info = Gregorian.info(endMoment, Time.FORMAT_SHORT);
        var startYear = info.year as Number;
        if ((info.month as Number) < 9) {
            startYear = startYear - 1;
        }
        return makeMoment(startYear, 9, 1, 0, 0);
    }

    // Derived next-year start: the 1st of September following the end.
    static function getNextYearStartMoment(endMoment as Time.Moment) as Time.Moment {
        var info = Gregorian.info(endMoment, Time.FORMAT_SHORT);
        var year = info.year as Number;
        if ((info.month as Number) >= 9) {
            year = year + 1;
        }
        return makeMoment(year, 9, 1, 0, 0);
    }

    static function getPercentComplete(now as Time.Moment) as Float {
        var endMoment = getCalibratedEndMoment();
        var startMoment = getYearStartMoment(endMoment);
        var s = startMoment.value();
        var e = endMoment.value();
        var n = now.value();
        if (e <= s) {
            return 0.0;
        }
        var p = (n - s).toFloat() / (e - s).toFloat();
        if (p < 0.0) { p = 0.0; }
        if (p > 1.0) { p = 1.0; }
        return p;
    }

    static function getDaysUntil(now as Time.Moment, target as Time.Moment) as Number {
        var d = target.value() - now.value();
        if (d < 0) { d = 0; }
        return d / SECONDS_PER_DAY;
    }

    // Splits a duration in seconds into [days, hours, minutes, seconds].
    static function breakdown(totalSeconds as Number) as Array<Number> {
        var s = totalSeconds;
        if (s < 0) { s = 0; }
        return [
            s / SECONDS_PER_DAY,
            (s % SECONDS_PER_DAY) / 3600,
            (s % 3600) / 60,
            s % 60
        ];
    }
}
