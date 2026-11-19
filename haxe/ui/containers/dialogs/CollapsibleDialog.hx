package haxe.ui.containers.dialogs;

import haxe.ui.Toolkit;
import haxe.ui.behaviours.DataBehaviour;
import haxe.ui.components.Image;
import haxe.ui.containers.dialogs.Dialog;
import haxe.ui.core.CompositeBuilder;
import haxe.ui.events.MouseEvent;

/**
 * A dialog with a minimize/maximize button in the title bar, which collapses the dialog body.
 */
@:composite(Builder)
class CollapsibleDialog extends Dialog {
    /**
     * Set this property to collapse/expand the dialog body.
     */
     @:clonable @:behaviour(Minimized, false)    public var minimized:Bool;
}

private class Minimized extends DataBehaviour {
    private var _expandedHeight:Null<Float> = null;

    public override function validateData() {
        var dialogContent = _component.findComponent("dialog-content", Box);
        if (dialogContent == null) {
            return;
        }
        var dialogFooterContainer = _component.findComponent("dialog-footer-container", Box);
        if (dialogFooterContainer == null) {
            return;
        }
        var hasFooterComponents = false;
        var dialogFooter = _component.findComponent("dialog-footer", Box);
        if (dialogFooter != null) {
            hasFooterComponents = dialogFooter.numComponents > 0;
        }
        var dialogMinMaxButton = _component.findComponent("dialog-minmax-button", Image);
        if (dialogMinMaxButton == null) {
            return;
        }
        if (_value) {
            // Collapse the dialog.
            if (dialogContent.hidden) {
                return;
            }
            dialogMinMaxButton.swapClass("dialog-maximize-button", "dialog-minimize-button");
            if (!_component.autoHeight) {
                var dialogTitle = _component.findComponent("dialog-title", Box);
                var style = _component.style;
                var collapsed:Float = _component.layout.paddingTop + _component.layout.paddingBottom;
                if (dialogTitle != null) {
                    collapsed += dialogTitle.height;
                }
                if (style != null) {
                    collapsed += (style.borderTopSize != null ? style.borderTopSize : 0) + (style.borderBottomSize != null ? style.borderBottomSize : 0);
                }
                _expandedHeight = _component.height;
                _component.height = collapsed;
            }
            dialogContent.hidden = true;
            dialogFooterContainer.hidden = true;
        } else {
            if (!dialogContent.hidden) {
                return;
            }
            dialogMinMaxButton.swapClass("dialog-minimize-button", "dialog-maximize-button");
            dialogContent.hidden = false;
            dialogFooterContainer.hidden = !hasFooterComponents;
            var restore:Null<Float> = _expandedHeight;
            _expandedHeight = null;
            if (restore != null) {
                _component.height = restore;
                Toolkit.callLater(function() {
                    if (!dialogContent.hidden) {
                        _component.height = restore;
                    }
                });
            }
        }
    }
}

@:dox(hide) @:noCompletion
private class Builder extends CompositeBuilder {
    private var _dialog:CollapsibleDialog;
    private var _dialogMinMaxButton:Image;

    public function new(dialog:CollapsibleDialog) {
        super(dialog);
        _dialog = dialog;
    }

    public override function onReady() {
        super.onReady();
        if (_dialogMinMaxButton != null) {
            return;
        }

        var dialogTitle = _component.findComponent("dialog-title", HBox, true);
        // Create the minimize/maximize button.
        _dialogMinMaxButton = new Image();
        _dialogMinMaxButton.id = "dialog-minmax-button";
        _dialogMinMaxButton.styleNames = "dialog-minimize-button";
        _dialogMinMaxButton.registerEvent(MouseEvent.CLICK, onMinMaxButton);
        _dialogMinMaxButton.registerEvent(MouseEvent.MOUSE_DOWN, cancelEvent);
        _dialogMinMaxButton.registerEvent(MouseEvent.DBL_CLICK, cancelEvent);
        _dialog.dialogCloseButton.registerEvent(MouseEvent.DBL_CLICK, cancelEvent);
        dialogTitle.addComponent(_dialogMinMaxButton);

        // Move the button before the close button
        dialogTitle.setComponentIndex(_dialogMinMaxButton, 1);

        dialogTitle.registerEvent(MouseEvent.DBL_CLICK, onMinMaxButton);
    }

    private function cancelEvent(e:MouseEvent) {
        e.cancel();
    }

    private function onMinMaxButton(_) {
        _dialog.minimized = !_dialog.minimized;
    }
}
