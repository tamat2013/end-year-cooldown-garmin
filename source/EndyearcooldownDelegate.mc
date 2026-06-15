import Toybox.Lang;
import Toybox.WatchUi;

// Handles switching between the year and today screens via START / ENTER,
// NEXT / PREV buttons, or a screen tap on touch devices.
class EndyearcooldownDelegate extends WatchUi.BehaviorDelegate {

    var _view as EndyearcooldownView;

    function initialize(view as EndyearcooldownView) {
        BehaviorDelegate.initialize();
        _view = view;
    }

    function onSelect() as Boolean {
        _view.nextScreen();
        return true;
    }

    function onNextPage() as Boolean {
        _view.nextScreen();
        return true;
    }

    function onPreviousPage() as Boolean {
        _view.previousScreen();
        return true;
    }

    function onTap(evt as WatchUi.ClickEvent) as Boolean {
        _view.nextScreen();
        return true;
    }
}
