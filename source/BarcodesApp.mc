using Toybox.Application as App;
using Toybox.Application.Storage as Storage;
using Toybox.WatchUi as Ui;

class BarcodesApp extends App.AppBase {

    function initialize() {
        AppBase.initialize();
    }

    function onStart(state) {
    }

    function onStop(state) {
    }

    function getInitialView() {
        var slots = CodeListView.getConfiguredSlots();
        if (slots.size() > 0) {
            var lastSlot = Storage.getValue("lastSlot");
            var slotPosition = 0;
            if (lastSlot != null) {
                for (var i = 0; i < slots.size(); i += 1) {
                    if (slots[i] == lastSlot) {
                        slotPosition = i;
                        break;
                    }
                }
            }
            var slotNumber = slots[slotPosition];
            Storage.setValue("lastSlot", slotNumber);
            return [ CodeListView.buildBarcodeView(slotNumber), new BarcodeDelegate(slots, slotPosition) ];
        }
        var menu = CodeListView.buildMenu();
        return [ menu, new CodeListDelegate() ];
    }

    function getGlanceView() {
        return [ new BarcodeGlanceView(), new BarcodeGlanceDelegate() ];
    }
}
