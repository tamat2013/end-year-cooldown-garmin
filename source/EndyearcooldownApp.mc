import Toybox.Application;
import Toybox.Lang;
import Toybox.WatchUi;

class EndyearcooldownApp extends Application.AppBase {

    function initialize() {
        AppBase.initialize();
    }

    // onStart() is called on application start up
    function onStart(state as Dictionary?) as Void {
    }

    // onStop() is called when your application is exiting
    function onStop(state as Dictionary?) as Void {
    }

    function onSettingsChanged() as Void {
        WatchUi.requestUpdate();
    }

    // Only compiled in for devices whose API supports WatchUi.GlanceView;
    // excluded automatically on older devices, which keep working with no glance.
    (:glance)
    function getGlanceView() as [ WatchUi.GlanceView ] or [ WatchUi.GlanceView, WatchUi.GlanceViewDelegate ] or Null {
        return [ new EndyearcooldownGlanceView() ];
    }

    // Return the initial view of your application here
    function getInitialView() as [Views] or [Views, InputDelegates] {
        var seed = Application.Properties.getValue("cooldownSeed") as String?;
        var config = (seed == null or seed.equals("")) ? null : CooldownConfig.parse(seed);
        if (config == null) {
            return [ new NoSeedView() ];
        }
        var view = new EndyearcooldownView(config);
        return [ view, new EndyearcooldownDelegate(view) ];
    }

}

function getApp() as EndyearcooldownApp {
    return Application.getApp() as EndyearcooldownApp;
}
