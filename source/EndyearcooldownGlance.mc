import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Time;
import Toybox.WatchUi;

// Compact carousel glance: title, days remaining, and a progress bar showing
// how much of the school year is already behind us.
(:glance)
class EndyearcooldownGlance extends WatchUi.GlanceView {

    function initialize() {
        GlanceView.initialize();
    }

    function onUpdate(dc as Dc) as Void {
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_BLACK);
        dc.clear();

        var w = dc.getWidth();
        var h = dc.getHeight();

        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(0, (h * 0.04).toNumber(), Graphics.FONT_TINY, "School End",
                    Graphics.TEXT_JUSTIFY_LEFT);

        var officialTs = CountdownUtil.numProp("OfficialEndDate");
        if (officialTs <= 0) {
            dc.drawText(0, (h * 0.52).toNumber(), Graphics.FONT_XTINY, "Set end date",
                        Graphics.TEXT_JUSTIFY_LEFT);
            return;
        }

        var now = Time.now();
        var endMoment = CountdownUtil.getCalibratedEndMoment();
        var secsLeft = endMoment.value() - now.value();
        if (secsLeft < 0) {
            secsLeft = 0;
        }
        var days = secsLeft / CountdownUtil.SECONDS_PER_DAY;

        dc.drawText(0, (h * 0.40).toNumber(), Graphics.FONT_SMALL,
                    Lang.format("$1$ Days left", [days]), Graphics.TEXT_JUSTIFY_LEFT);

        // Horizontal progress bar (percentage of the school year completed).
        var p = CountdownUtil.getPercentComplete(now);
        var barY = (h * 0.82).toNumber();
        var barH = (h * 0.12).toNumber();
        if (barH < 3) {
            barH = 3;
        }

        dc.setColor(Graphics.COLOR_DK_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(0, barY, w, barH);
        dc.setColor(Graphics.COLOR_GREEN, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(0, barY, (p * w).toNumber(), barH);
    }
}
