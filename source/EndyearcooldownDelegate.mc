import Toybox.Lang;
import Toybox.WatchUi;

// Scrolling (NEXT / PREV) switches which date is showing; a press (START or
// a screen tap) toggles that date between its regular and net countdown.
class EndyearcooldownDelegate extends WatchUi.BehaviorDelegate {

    var _view as EndyearcooldownView;

    function initialize(view as EndyearcooldownView) {
        BehaviorDelegate.initialize();
        _view = view;
    }

    function onSelect() as Boolean {
        _view.toggleMode();
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

    function onTap(evt as WatchUi.ClickEvent) as Boolean {
        _view.toggleMode();
        return true;
    }
}
