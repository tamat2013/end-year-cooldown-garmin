import Toybox.Application;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.WatchUi;
import Toybox.Time;

// Glance-bar summary shown on devices that support WatchUi.GlanceView.
// Excluded automatically at build time on devices without glance support.
(:glance)
class EndyearcooldownGlanceView extends WatchUi.GlanceView {

    function initialize() {
        GlanceView.initialize();
    }

    function onUpdate(dc as Graphics.Dc) as Void {
        View.onUpdate(dc);

        var seed = Application.Properties.getValue("cooldownSeed") as String?;
        var config = (seed == null or seed.equals("")) ? null : CooldownConfig.parse(seed);

        var text;
        if (config == null) {
            text = "Tap to set up";
        } else {
            var remaining = config.officialEndEpoch - Time.now().value();
            var days = remaining / 86400;
            if (days > 0) {
                text = days.format("%d") + (days == 1 ? " day left" : " days left");
            } else {
                text = "Last day!";
            }
        }

        dc.drawText(0, dc.getHeight() / 2, Graphics.FONT_GLANCE, text, Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);
    }
}
