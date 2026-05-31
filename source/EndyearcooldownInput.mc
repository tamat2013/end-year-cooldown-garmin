import Toybox.Lang;
import Toybox.WatchUi;

// Intercepts page up / page down to toggle between the two countdown screens.
class EndyearcooldownInput extends WatchUi.BehaviorDelegate {

    function initialize() {
        BehaviorDelegate.initialize();
    }

    function onNextPage() as Boolean {
        EndyearcooldownMainView.nextPage();
        WatchUi.requestUpdate();
        return true;
    }

    function onPreviousPage() as Boolean {
        EndyearcooldownMainView.previousPage();
        WatchUi.requestUpdate();
        return true;
    }
}
