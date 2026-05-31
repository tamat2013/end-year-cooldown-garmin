import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Math;
import Toybox.Time;
import Toybox.Time.Gregorian;
import Toybox.Timer;
import Toybox.WatchUi;

class EndyearcooldownMainView extends WatchUi.View {

    // Only one instance exists, so the current page is shared statically with
    // the behavior delegate (which is constructed independently).
    static var sPage = 0;

    static function nextPage() as Void {
        sPage = (sPage + 1) % 2;
    }

    static function previousPage() as Void {
        sPage = (sPage + 1) % 2;
    }

    private var mTimer as Timer.Timer?;
    private var mInterval as Number = -1;
    private var mAnim as Number = 0;

    function initialize() {
        View.initialize();
    }

    function onShow() as Void {
        startTimer(1000);
        WatchUi.requestUpdate();
    }

    function onHide() as Void {
        if (mTimer != null) {
            mTimer.stop();
        }
        mInterval = -1;
    }

    function onTick() as Void {
        WatchUi.requestUpdate();
    }

    // Restart the redraw timer only when the desired cadence changes.
    private function startTimer(intervalMs as Number) as Void {
        if (mInterval == intervalMs) {
            return;
        }
        if (mTimer == null) {
            mTimer = new Timer.Timer();
        }
        mTimer.stop();
        mTimer.start(method(:onTick), intervalMs, true);
        mInterval = intervalMs;
    }

    function onUpdate(dc as Dc) as Void {
        // No ghosting: always clear to a solid background first.
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_BLACK);
        dc.clear();

        var officialTs = CountdownUtil.numProp("OfficialEndDate");
        if (officialTs <= 0) {
            startTimer(1000);
            drawMessage(dc, "Set end date\nin settings");
            return;
        }

        var now = Time.now();
        var endMoment = CountdownUtil.getCalibratedEndMoment();
        var endValue = endMoment.value();
        var nowValue = now.value();

        if (nowValue < endValue) {
            startTimer(1000);
            if (sPage == 0) {
                drawCountdownPage(dc, endValue - nowValue, "CONTINUOUS");
            } else {
                drawCountdownPage(dc, CountdownUtil.getNetSecondsRemaining(now), "SCHOOL HOURS");
            }
        } else if (nowValue < endValue + CountdownUtil.CELEBRATION_SECONDS) {
            // Faster cadence drives the fireworks animation.
            startTimer(50);
            mAnim += 1;
            drawFireworks(dc);
        } else {
            startTimer(1000);
            drawSummer(dc, now);
        }
    }

    // ------------------------------------------------------------------ //
    //  Drawing helpers                                                    //
    // ------------------------------------------------------------------ //

    private function drawCountdownPage(dc as Dc, totalSeconds as Number, title as String) as Void {
        var w = dc.getWidth();
        var h = dc.getHeight();
        var cx = (w / 2).toNumber();

        var parts = CountdownUtil.breakdown(totalSeconds);
        var days = parts[0];
        var hours = parts[1];
        var mins = parts[2];
        var secs = parts[3];

        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, (h * 0.10).toNumber(), Graphics.FONT_TINY, title,
                    Graphics.TEXT_JUSTIFY_CENTER);

        // Remaining days: the very large hero number.
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, (h * 0.24).toNumber(), Graphics.FONT_NUMBER_HOT, days.format("%d"),
                    Graphics.TEXT_JUSTIFY_CENTER);

        dc.setColor(Graphics.COLOR_YELLOW, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, (h * 0.60).toNumber(), Graphics.FONT_XTINY, "DAYS LEFT",
                    Graphics.TEXT_JUSTIFY_CENTER);

        // Hours / minutes / seconds underneath, with a safe vertical gap.
        var hms = Lang.format("$1$:$2$:$3$",
            [hours.format("%02d"), mins.format("%02d"), secs.format("%02d")]);
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, (h * 0.74).toNumber(), Graphics.FONT_SMALL, hms,
                    Graphics.TEXT_JUSTIFY_CENTER);
    }

    private function drawFireworks(dc as Dc) as Void {
        var w = dc.getWidth();
        var h = dc.getHeight();
        var cx = (w / 2).toNumber();
        var cy = (h / 2).toNumber();
        var maxR = ((h < w ? h : w) / 2).toNumber();

        var phase = mAnim % 24;
        var r = (phase * maxR / 24).toNumber();

        var colors = [Graphics.COLOR_RED, Graphics.COLOR_YELLOW, Graphics.COLOR_GREEN,
                      Graphics.COLOR_BLUE, Graphics.COLOR_PURPLE, Graphics.COLOR_ORANGE];
        var c = colors[(mAnim / 4) % colors.size()];
        dc.setColor(c, Graphics.COLOR_TRANSPARENT);

        // Radiating sparks expanding outward from the centre.
        for (var i = 0; i < 12; i++) {
            var ang = Math.PI * 2.0 * i / 12.0;
            var ex = (cx + r * Math.cos(ang)).toNumber();
            var ey = (cy + r * Math.sin(ang)).toNumber();
            dc.drawLine(cx, cy, ex, ey);
            dc.fillCircle(ex, ey, 3);
        }
        dc.drawCircle(cx, cy, r);

        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, (h * 0.04).toNumber(), Graphics.FONT_SMALL, "SCHOOL'S OUT!",
                    Graphics.TEXT_JUSTIFY_CENTER);
    }

    private function drawSummer(dc as Dc, now as Time.Moment) as Void {
        var w = dc.getWidth();
        var h = dc.getHeight();
        var cx = (w / 2).toNumber();

        var endMoment = CountdownUtil.getCalibratedEndMoment();
        var nextStart = CountdownUtil.getNextYearStartMoment(endMoment);
        var daysLeft = CountdownUtil.getDaysUntil(now, nextStart);

        var info = Gregorian.info(nextStart, Time.FORMAT_MEDIUM);
        var dateStr = Lang.format("$1$ $2$", [info.month, info.day]);

        dc.setColor(Graphics.COLOR_YELLOW, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, (h * 0.12).toNumber(), Graphics.FONT_SMALL, "SUMMER BREAK",
                    Graphics.TEXT_JUSTIFY_CENTER);

        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, (h * 0.30).toNumber(), Graphics.FONT_NUMBER_MEDIUM, daysLeft.format("%d"),
                    Graphics.TEXT_JUSTIFY_CENTER);

        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, (h * 0.62).toNumber(), Graphics.FONT_XTINY, "DAYS TO RETURN",
                    Graphics.TEXT_JUSTIFY_CENTER);
        dc.drawText(cx, (h * 0.76).toNumber(), Graphics.FONT_TINY, dateStr,
                    Graphics.TEXT_JUSTIFY_CENTER);
    }

    private function drawMessage(dc as Dc, msg as String) as Void {
        var w = dc.getWidth();
        var h = dc.getHeight();
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText((w / 2).toNumber(), (h / 2).toNumber(), Graphics.FONT_SMALL, msg,
                    Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }
}
