import Toybox.Application;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Time;
import Toybox.Time.Gregorian;
import Toybox.Timer;
import Toybox.WatchUi;

class EndyearcooldownView extends WatchUi.View {

    const PROP_OFFICIAL_END_DATE = "officialEndDate";
    const PROP_ADJOINING_DAYS_OFF = "adjoiningDaysOff";
    const PROP_NEXT_YEAR_START_DATE = "nextYearStartDate";

    const PROP_SUNDAY_END = "sundayEnd";
    const PROP_MONDAY_END = "mondayEnd";
    const PROP_TUESDAY_END = "tuesdayEnd";
    const PROP_WEDNESDAY_END = "wednesdayEnd";
    const PROP_THURSDAY_END = "thursdayEnd";
    const PROP_FRIDAY_END = "fridayEnd";
    const PROP_SATURDAY_END = "saturdayEnd";

    const PROP_SUNDAY_ENABLED = "sundayEnabled";
    const PROP_MONDAY_ENABLED = "mondayEnabled";
    const PROP_TUESDAY_ENABLED = "tuesdayEnabled";
    const PROP_WEDNESDAY_ENABLED = "wednesdayEnabled";
    const PROP_THURSDAY_ENABLED = "thursdayEnabled";
    const PROP_FRIDAY_ENABLED = "fridayEnabled";
    const PROP_SATURDAY_ENABLED = "saturdayEnabled";

    var _timer as Timer.Timer?;

    function initialize() {
        View.initialize();
        _timer = new Timer.Timer();
    }

    function onLayout(dc as Dc) as Void {
    }

    function onShow() as Void {
        if (_timer != null) {
            (_timer as Timer.Timer).start(method(:onTick), 1000, true);
        }
    }

    function onHide() as Void {
        if (_timer != null) {
            (_timer as Timer.Timer).stop();
        }
    }

    function onTick() as Void {
        WatchUi.requestUpdate();
    }

    function onUpdate(dc as Dc) as Void {
        var now = Time.now();
        var schoolEndsAt = getSchoolEndsAt();
        var nextYearStartsAt = getNextYearStartsAt();
        var schoolRemaining = schoolEndsAt.value() - now.value();

        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);

        if (schoolRemaining >= 0) {
            drawSchoolCountdown(dc, schoolRemaining);
        } else {
            drawVacationCountdown(dc, nextYearStartsAt, nextYearStartsAt.value() - now.value());
        }
    }

    function drawSchoolCountdown(dc as Dc, remainingSeconds as Number) as Void {
        var width = dc.getWidth();
        var height = dc.getHeight();
        var bodyFont = (width >= 240) ? Graphics.FONT_NUMBER_MEDIUM : Graphics.FONT_NUMBER_MILD;

        if (remainingSeconds <= 0) {
            drawCentered(dc, "School is over!", width / 2, height * 18 / 100, Graphics.FONT_SMALL);
            drawCelebration(dc, width, height);
            return;
        }

        if (remainingSeconds <= 10) {
            drawCentered(dc, remainingSeconds.format("%d"), width / 2, height * 44 / 100, bodyFont);
            drawCentered(dc, "seconds", width / 2, height * 68 / 100, Graphics.FONT_XTINY);
            return;
        }

        var days = remainingSeconds / 86400;
        var rest = remainingSeconds % 86400;
        var hours = rest / 3600;
        rest = rest % 3600;
        var minutes = rest / 60;
        var seconds = rest % 60;

        drawCentered(dc, "School ends in", width / 2, height * 18 / 100, Graphics.FONT_SMALL);

        if (days > 0) {
            drawCentered(dc, days.format("%d") + " days", width / 2, height * 38 / 100, Graphics.FONT_LARGE);
            drawCentered(dc, twoDigits(hours) + ":" + twoDigits(minutes) + ":" + twoDigits(seconds), width / 2, height * 60 / 100, bodyFont);
            drawCentered(dc, "summer is close", width / 2, height * 82 / 100, Graphics.FONT_XTINY);
        } else if (hours > 0) {
            drawCentered(dc, hours.format("%d") + ":" + twoDigits(minutes) + ":" + twoDigits(seconds), width / 2, height * 50 / 100, bodyFont);
            drawCentered(dc, "hours left", width / 2, height * 72 / 100, Graphics.FONT_XTINY);
        } else if (minutes > 0) {
            drawCentered(dc, minutes.format("%d") + ":" + twoDigits(seconds), width / 2, height * 50 / 100, bodyFont);
            drawCentered(dc, "minutes left", width / 2, height * 72 / 100, Graphics.FONT_XTINY);
        } else {
            drawCentered(dc, seconds.format("%d"), width / 2, height * 50 / 100, bodyFont);
            drawCentered(dc, "seconds", width / 2, height * 72 / 100, Graphics.FONT_XTINY);
        }
    }

    function drawVacationCountdown(dc as Dc, nextYearStartsAt as Time.Moment, remainingSeconds as Number) as Void {
        var width = dc.getWidth();
        var height = dc.getHeight();
        var info = Gregorian.info(nextYearStartsAt, Time.FORMAT_SHORT);
        var daysLeft = 0;

        if (remainingSeconds > 0) {
            daysLeft = (remainingSeconds + 86399) / 86400;
        }

        drawCentered(dc, "Summer break", width / 2, height * 18 / 100, Graphics.FONT_SMALL);
        drawCentered(dc, "Back: " + dateLabel(info), width / 2, height * 42 / 100, Graphics.FONT_SMALL);
        drawCentered(dc, daysLeft.format("%d"), width / 2, height * 64 / 100, Graphics.FONT_NUMBER_MEDIUM);
        drawCentered(dc, "days left", width / 2, height * 84 / 100, Graphics.FONT_XTINY);
    }

    function drawCentered(dc as Dc, text as String, x as Number, y as Number, font as Graphics.FontType) as Void {
        dc.drawText(x, y, font, text, Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    function drawCelebration(dc as Dc, width as Number, height as Number) as Void {
        var centerX = width / 2;
        var centerY = height * 56 / 100;
        dc.drawLine(centerX, centerY, centerX - 24, centerY - 22);
        dc.drawLine(centerX, centerY, centerX + 24, centerY - 22);
        dc.drawLine(centerX, centerY, centerX - 20, centerY + 26);
        dc.drawLine(centerX, centerY, centerX + 20, centerY + 26);
        drawCentered(dc, "*", centerX - 32, centerY - 34, Graphics.FONT_SMALL);
        drawCentered(dc, "*", centerX + 32, centerY - 34, Graphics.FONT_SMALL);
        drawCentered(dc, "*", centerX - 28, centerY + 32, Graphics.FONT_SMALL);
        drawCentered(dc, "*", centerX + 28, centerY + 32, Graphics.FONT_SMALL);
        drawCentered(dc, "Happy break!", centerX, height * 84 / 100, Graphics.FONT_XTINY);
    }

    function findLastEnabledSchoolDay(day as Time.Moment) as Time.Moment {
        if (!isAnyWeekdayEnabled()) {
            return day;
        }

        var oneDay = new Time.Duration(86400);
        var candidate = day;
        while (!isDayEnabled(Gregorian.info(candidate, Time.FORMAT_SHORT).day_of_week)) {
            candidate = candidate.subtract(oneDay);
        }

        return candidate;
    }

    function isDayEnabled(dayOfWeek as Number) as Boolean {
        switch (dayOfWeek) {
            case 1:
                return getBooleanProperty(PROP_SUNDAY_ENABLED, true);
            case 2:
                return getBooleanProperty(PROP_MONDAY_ENABLED, true);
            case 3:
                return getBooleanProperty(PROP_TUESDAY_ENABLED, true);
            case 4:
                return getBooleanProperty(PROP_WEDNESDAY_ENABLED, true);
            case 5:
                return getBooleanProperty(PROP_THURSDAY_ENABLED, true);
            case 6:
                return getBooleanProperty(PROP_FRIDAY_ENABLED, true);
            case 7:
                return getBooleanProperty(PROP_SATURDAY_ENABLED, false);
        }

        return false;
    }

    function isAnyWeekdayEnabled() as Boolean {
        return getBooleanProperty(PROP_SUNDAY_ENABLED, true)
            or getBooleanProperty(PROP_MONDAY_ENABLED, true)
            or getBooleanProperty(PROP_TUESDAY_ENABLED, true)
            or getBooleanProperty(PROP_WEDNESDAY_ENABLED, true)
            or getBooleanProperty(PROP_THURSDAY_ENABLED, true)
            or getBooleanProperty(PROP_FRIDAY_ENABLED, true)
            or getBooleanProperty(PROP_SATURDAY_ENABLED, false);
    }

    function getSchoolEndsAt() as Time.Moment {
        var endDate = getDateParts(getPropertyValue(PROP_OFFICIAL_END_DATE), 2026, 6, 30);
        var adjoiningDaysOff = getNumberProperty(PROP_ADJOINING_DAYS_OFF, 0);
        var lastSchoolDay = dateOnlyMoment(endDate[0], endDate[1], endDate[2]).subtract(new Time.Duration(adjoiningDaysOff * 86400));
        lastSchoolDay = findLastEnabledSchoolDay(lastSchoolDay);
        var lastDayInfo = Gregorian.info(lastSchoolDay, Time.FORMAT_SHORT);
        var endTime = getEndTimeForDay(lastDayInfo.day_of_week);

        return Gregorian.moment({
            :year => lastDayInfo.year,
            :month => lastDayInfo.month,
            :day => lastDayInfo.day,
            :hour => endTime[0],
            :minute => endTime[1],
            :second => 0
        });
    }

    function getNextYearStartsAt() as Time.Moment {
        var startDate = getDateParts(getPropertyValue(PROP_NEXT_YEAR_START_DATE), 2026, 9, 1);
        return dateOnlyMoment(startDate[0], startDate[1], startDate[2]);
    }

    function dateOnlyMoment(year as Number, month as Number, day as Number) as Time.Moment {
        return Gregorian.moment({
            :year => year,
            :month => month,
            :day => day,
            :hour => 0,
            :minute => 0,
            :second => 0
        });
    }

    function getEndTimeForDay(dayOfWeek as Number) as Array<Number> {
        if (dayOfWeek == 1) {
            return getTimeParts(getPropertyValue(PROP_SUNDAY_END), 14, 0);
        } else if (dayOfWeek == 2) {
            return getTimeParts(getPropertyValue(PROP_MONDAY_END), 14, 0);
        } else if (dayOfWeek == 3) {
            return getTimeParts(getPropertyValue(PROP_TUESDAY_END), 14, 0);
        } else if (dayOfWeek == 4) {
            return getTimeParts(getPropertyValue(PROP_WEDNESDAY_END), 14, 0);
        } else if (dayOfWeek == 5) {
            return getTimeParts(getPropertyValue(PROP_THURSDAY_END), 14, 0);
        } else if (dayOfWeek == 6) {
            return getTimeParts(getPropertyValue(PROP_FRIDAY_END), 12, 0);
        }

        return getTimeParts(getPropertyValue(PROP_SATURDAY_END), 14, 0);
    }

    function getPropertyValue(key as String) as Object? {
        return Application.getApp().getProperty(key);
    }

    function getNumberProperty(key as String, defaultValue as Number) as Number {
        var value = getPropertyValue(key);
        if (value instanceof Number) {
            return value as Number;
        }
        if (value instanceof String) {
            return (value as String).toNumber();
        }
        return defaultValue;
    }

    function getBooleanProperty(key as String, defaultValue as Boolean) as Boolean {
        var value = getPropertyValue(key);
        if (value instanceof Boolean) {
            return value as Boolean;
        }
        if (value instanceof Number) {
            return (value as Number) != 0;
        }
        if (value instanceof String) {
            var text = value as String;
            return (text == "true") or (text == "True") or (text == "TRUE") or (text == "1");
        }
        return defaultValue;
    }

    function getDateParts(value as Object?, defaultYear as Number, defaultMonth as Number, defaultDay as Number) as Array<Number> {
        if (value instanceof Number) {
            var utcInfo = Gregorian.utcInfo(new Time.Moment(value as Number), Time.FORMAT_SHORT);
            return [ utcInfo.year, utcInfo.month, utcInfo.day ];
        }

        if (value instanceof String) {
            var text = value as String;
            if (text.length() >= 10) {
                return [
                    text.substring(0, 4).toNumber(),
                    text.substring(5, 7).toNumber(),
                    text.substring(8, 10).toNumber()
                ];
            }
        }

        return [ defaultYear, defaultMonth, defaultDay ];
    }

    function getTimeParts(value as Object?, defaultHour as Number, defaultMinute as Number) as Array<Number> {
        if (value instanceof String) {
            var text = value as String;
            if (text.length() >= 5) {
                return [
                    text.substring(0, 2).toNumber(),
                    text.substring(3, 5).toNumber()
                ];
            }
        }

        return [ defaultHour, defaultMinute ];
    }

    function twoDigits(value as Number) as String {
        if (value < 10) {
            return "0" + value.format("%d");
        }

        return value.format("%d");
    }

    function dateLabel(info) as String {
        return twoDigits(info.day) + "/" + twoDigits(info.month) + "/" + info.year.format("%d");
    }
}
