using Toybox.WatchUi as Ui;
using Toybox.Application.Storage as Storage;

class BarcodeDelegate extends Ui.BehaviorDelegate {

    var mSlots;
    var mPosition;

    function initialize(slots, position) {
        BehaviorDelegate.initialize();
        mSlots = slots;
        mPosition = position;
    }

    function onNextPage() {
        showSlot(mPosition + 1);
        return true;
    }

    function onPreviousPage() {
        showSlot(mPosition - 1);
        return true;
    }

    function showSlot(position) {
        if (position >= mSlots.size()) {
            position = 0;
        } else if (position < 0) {
            position = mSlots.size() - 1;
        }
        mPosition = position;
        var slotNumber = mSlots[mPosition];
        Storage.setValue("lastSlot", slotNumber);
        Ui.switchToView(
            CodeListView.buildBarcodeView(slotNumber),
            new BarcodeDelegate(mSlots, mPosition),
            Ui.SLIDE_IMMEDIATE
        );
    }

    function onBack() {
        Ui.popView(Ui.SLIDE_RIGHT);
        return true;
    }
}
