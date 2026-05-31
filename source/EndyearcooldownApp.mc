import Toybox.Application;
import Toybox.Lang;
import Toybox.WatchUi;

class EndyearcooldownApp extends Application.AppBase {

    function initialize() {
        AppBase.initialize();
    }

    function onStart(state as Dictionary?) as Void {
    }

    function onStop(state as Dictionary?) as Void {
    }

    // The main view plus the behavior delegate that drives page scrolling.
    function getInitialView() as [Views] or [Views, InputDelegates] {
        return [ new EndyearcooldownMainView(), new EndyearcooldownInput() ];
    }

    // Lightweight glance shown in the widget carousel.
    (:glance)
    function getGlanceView() as [GlanceView] or [GlanceView, GlanceViewDelegate] or Null {
        return [ new EndyearcooldownGlance() ];
    }

    // Settings changed on the phone: drop cached maths and redraw.
    function onSettingsChanged() as Void {
        CountdownUtil.invalidateCache();
        WatchUi.requestUpdate();
    }
}

function getApp() as EndyearcooldownApp {
    return Application.getApp() as EndyearcooldownApp;
}
