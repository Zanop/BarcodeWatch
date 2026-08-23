using Toybox.WatchUi as Ui;

(:glance)
class BarcodeGlanceDelegate extends Ui.GlanceViewDelegate {

    function initialize() {
        GlanceViewDelegate.initialize();
    }

    function onGlanceEvent(event) {
        Ui.switchToView(CodeListView.buildMenu(), new CodeListDelegate(), Ui.SLIDE_IMMEDIATE);
        return true;
    }
}