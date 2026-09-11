import Toybox.Lang;
import Toybox.WatchUi;

// Delegate for the widget's initial view. Garmin restricts touch input on a
// widget's *initial* view to select/tap only - swipe never reaches it on
// touch-only devices like vivoactive4s (confirmed by Garmin staff:
// https://forums.garmin.com/developer/connect-iq/f/discussion/258395/behaviordelegate-and-vivoactive4).
// Without this, a swipe meant to change dates falls through unhandled and
// the platform treats it as "back", exiting the widget entirely.
//
// A select ("press") here "enters" the widget by pushing the same view with
// a second delegate, which - not being the initial view - receives full
// swipe/back input. Physical NEXT/PREV buttons work on the initial view too,
// so they're wired here directly as a shortcut.
class EndyearcooldownDelegate extends WatchUi.BehaviorDelegate {

    var _view as EndyearcooldownView;

    function initialize(view as EndyearcooldownView) {
        BehaviorDelegate.initialize();
        _view = view;
    }

    function onSelect() as Boolean {
        WatchUi.pushView(_view, new EndyearcooldownActiveDelegate(_view), WatchUi.SLIDE_IMMEDIATE);
        return true;
    }

    function onNextPage() as Boolean {
        _view.nextDate();
        return true;
    }

    function onPreviousPage() as Boolean {
        _view.previousDate();
        return true;
    }
}

// Delegate for the pushed, "entered" view: scrolling (NEXT/PREV, or a swipe
// once swipe input actually reaches this non-initial view) switches which
// date is showing; a press toggles that date between regular and net. Back
// pops out to the widget's initial view instead of exiting the widget.
class EndyearcooldownActiveDelegate extends WatchUi.BehaviorDelegate {

    var _view as EndyearcooldownView;

    function initialize(view as EndyearcooldownView) {
        BehaviorDelegate.initialize();
        _view = view;
    }

    function onNextPage() as Boolean {
        _view.nextDate();
        return true;
    }

    function onPreviousPage() as Boolean {
        _view.previousDate();
        return true;
    }

    function onSelect() as Boolean {
        _view.toggleMode();
        return true;
    }

    function onTap(evt as WatchUi.ClickEvent) as Boolean {
        _view.toggleMode();
        return true;
    }

    function onBack() as Boolean {
        WatchUi.popView(WatchUi.SLIDE_IMMEDIATE);
        return true;
    }
}
